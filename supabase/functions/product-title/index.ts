// product-title: read-only helper for ClosetIQ Studio.
// POST { url } (Amazon product link or short link) -> { asin, title, short_title, brand, final_url }
// Only Amazon hosts are followed (no open proxy / SSRF). Only the signed-in Studio owner may call it.
const CORS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, apikey, content-type, x-test-key",
  "access-control-allow-methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...CORS, "content-type": "application/json" } });

const SHORT = /^(amzn\.to|a\.co|amzn\.eu|amzn\.asia|link\.amazon|www\.link\.amazon|amzlinks\.in)$/i;
const STORE = /^(www\.|smile\.|m\.)?amazon\.(com|ca|co\.uk|de|fr|it|es|com\.mx|com\.au|co\.jp|in)$/i;
const okHost = (h: string) => SHORT.test(h) || STORE.test(h);
const UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1";
const UA2 = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36";

function asinOf(u: URL): string | null {
  const m = u.pathname.match(/\/(?:dp|gp\/product|gp\/aw\/d|product)\/([A-Z0-9]{10})(?=[/?#]|$)/i) || u.pathname.match(/\/(B[0-9A-Z]{9})(?=[/?#]|$)/i);
  return m ? m[1].toUpperCase() : null;
}
const decode = (s: string) => s.replace(/&quot;|&#34;/g, '"').replace(/&#39;|&apos;/g, "'").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&#(\d+);/g, (_, n) => String.fromCharCode(+n)).replace(/\s+/g, " ").trim();

async function resolve(input: string): Promise<URL> {
  let u = new URL(input);
  for (let i = 0; i < 6; i++) {
    if (u.protocol !== "https:" && u.protocol !== "http:") throw new Error("bad_url");
    if (!okHost(u.hostname)) throw new Error("not_amazon");
    if (STORE.test(u.hostname) && asinOf(u)) return u;
    const r = await fetch(u, { method: "GET", redirect: "manual", headers: { "user-agent": UA2 } });
    await r.body?.cancel();
    const loc = r.headers.get("location");
    if (!loc || r.status < 300 || r.status >= 400) return u;
    u = new URL(loc, u);
  }
  return u;
}

async function titleFor(asin: string, host: string) {
  for (const ua of [UA2, UA]) {
    const r = await fetch(`https://${host}/dp/${asin}`, { headers: { "user-agent": ua, accept: "text/html,application/xhtml+xml", "accept-language": "en-US,en;q=0.9" } });
    const html = await r.text();
    if (/captcha|validateCaptcha|api-services-support@amazon\.com/i.test(html) && !/id="productTitle"/.test(html)) continue;
    const pt = html.match(/id="productTitle"[^>]*>([\s\S]*?)<\/span>/i)?.[1];
    const og = html.match(/<meta[^>]+(?:property|name)="og:title"[^>]+content="([^"]+)"/i)?.[1];
    const t = html.match(/<title>([\s\S]*?)<\/title>/i)?.[1];
    const by = html.match(/id="bylineInfo"[^>]*>([\s\S]*?)<\/a>/i)?.[1];
    const full = decode(t || og || "").replace(/^Amazon\.[a-z.]+\s*:\s*/i, "").replace(/\s+at Amazon\b.*$/i, "").replace(/\s*:\s*(Clothing|Shoes|Jewelry|Amazon Fashion).*$/i, "");
    const short = decode(pt || "") || full.split(/\s[|,]\s|\s-\s/)[0];
    const brand = by ? decode(by.replace(/<[^>]*>/g, "")).replace(/^Visit the\s+|\s+Store$|^Brand:\s*/gi, "") : "";
    if (!short && !full) continue;
    return { title: full || short, short_title: short.length > 80 ? short.slice(0, 80).replace(/[\s,;|-]+\S*$/, "") : short, brand: brand.slice(0, 40) };
  }
  return null;
}

async function allowed(req: Request): Promise<boolean> {
  const test = Deno.env.get("PRODUCT_TITLE_TEST_KEY");
  if (test && req.headers.get("x-test-key") === test) return true;
  const auth = req.headers.get("authorization") || "";
  if (!auth.startsWith("Bearer ")) return false;
  const r = await fetch(Deno.env.get("SUPABASE_URL") + "/auth/v1/user", { headers: { authorization: auth, apikey: Deno.env.get("SUPABASE_ANON_KEY")! } });
  if (!r.ok) return false;
  const u = await r.json();
  const allow = (Deno.env.get("STUDIO_ALLOWED_EMAIL") || "").toLowerCase().split(/[,\s]+/).filter(Boolean);
  return !!u?.email && (allow.length === 0 || allow.includes(String(u.email).toLowerCase()));
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method" }, 405);
  if (!(await allowed(req))) return json({ error: "unauthorized" }, 401);
  let url = "";
  try { url = String((await req.json()).url || "").trim(); } catch { /* */ }
  const m = url.match(/https?:\/\/\S+/); if (m) url = m[0];   // accept pasted share text
  if (!url) return json({ error: "missing_url" }, 400);
  try {
    const fin = await resolve(url);
    const asin = asinOf(fin);
    if (!asin) return json({ error: "no_asin", final_url: fin.toString() }, 200);
    const host = STORE.test(fin.hostname) ? fin.hostname : "www.amazon.com";
    const t = await titleFor(asin, host);
    return json({ asin, final_url: `https://${host}/dp/${asin}`, ...(t || { title: "", short_title: "", brand: "", blocked: true }) });
  } catch (e) {
    return json({ error: String((e as Error).message || e) }, 400);
  }
});
