// Paste-a-URL import. Deploy to a NEW Supabase project. Do not deploy over the
// production `studio` function. Requires a signed-in creator. Returns public
// page metadata only; the app saves the item after the creator confirms it.
import { assertPublicHttpsUrl, extractProductMeta } from "../_shared/product_meta.js";

const MAX_BYTES = 1_500_000;
const MAX_REDIRECTS = 4;
const TIMEOUT_MS = 8000;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return cors(new Response(null, { status: 204 }));
  if (req.method !== "POST") return json({ ok: false, message: "Use POST." }, 405);

  const auth = req.headers.get("Authorization") || "";
  if (!auth.startsWith("Bearer ")) return json({ ok: false, message: "Sign in required." }, 401);
  const user = await supabaseUser(auth);
  if (!user) return json({ ok: false, message: "Sign in required." }, 401);

  let body: { url?: string };
  try {
    body = await req.json();
  } catch {
    return json({ ok: false, message: "Missing a product link." }, 400);
  }

  try {
    const page = await readPublicHtml(String(body.url || ""));
    const meta = extractProductMeta(page.html, page.url);
    if (!meta.hasAny) {
      return json({ ok: false, fallback: true, message: "That page didn't share a name, photo or price. Add the details yourself." });
    }
    return json({
      ok: true,
      source_url: page.url,
      name: meta.name,
      image_url: meta.imageUrl,
      price_text: meta.priceText,
      currency: meta.currency,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Couldn't read that page.";
    return json({ ok: false, fallback: true, message: `${message} Add the photo, name and price yourself.` });
  }
});

async function supabaseUser(auth: string): Promise<boolean> {
  const base = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_ANON_KEY");
  if (!base || !key) return false;
  const response = await fetch(`${base}/auth/v1/user`, {
    headers: { Authorization: auth, apikey: key },
  });
  return response.ok;
}

async function readPublicHtml(raw: string): Promise<{ url: string; html: string }> {
  let current = assertPublicHttpsUrl(raw);
  for (let hop = 0; hop <= MAX_REDIRECTS; hop++) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
    let response: Response;
    try {
      response = await fetch(current, {
        redirect: "manual",
        signal: controller.signal,
        headers: {
          Accept: "text/html,application/xhtml+xml",
          "User-Agent": "ClosetIQStudioBot/1.0 (+https://closetiq.app)",
        },
      });
    } catch {
      throw new Error("Couldn't open that page.");
    } finally {
      clearTimeout(timer);
    }
    if (response.status >= 300 && response.status < 400) {
      const next = response.headers.get("location");
      if (!next) throw new Error("That page redirected without a destination.");
      current = assertPublicHttpsUrl(new URL(next, current).toString());
      continue;
    }
    if (!response.ok) throw new Error("That page didn't respond.");
    const type = (response.headers.get("content-type") || "").toLowerCase();
    if (type && !type.includes("html") && !type.includes("xml") && !type.includes("text/plain")) {
      throw new Error("That link isn't a product page.");
    }
    const reader = response.body?.getReader();
    if (!reader) throw new Error("That page was empty.");
    const chunks: Uint8Array[] = [];
    let size = 0;
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > MAX_BYTES) {
        await reader.cancel();
        throw new Error("That page is too large to import.");
      }
      chunks.push(value);
    }
    const html = new TextDecoder().decode(concat(chunks, size));
    return { url: current.toString(), html };
  }
  throw new Error("That page redirected too many times.");
}

function concat(chunks: Uint8Array[], size: number): Uint8Array {
  const out = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    out.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return out;
}

function json(body: unknown, status = 200): Response {
  return cors(new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  }));
}

function cors(response: Response): Response {
  const headers = new Headers(response.headers);
  headers.set("access-control-allow-origin", "*");
  headers.set("access-control-allow-headers", "authorization, content-type, apikey");
  headers.set("access-control-allow-methods", "POST, OPTIONS");
  return new Response(response.body, { status: response.status, headers });
}
