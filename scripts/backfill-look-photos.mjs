// Copy missing look-item photos from the private studio bucket into the public shop bucket.
// Requires the service role (storage RLS rejects the anon key). Does not remove or reorder items.
//
//   SUPABASE_SERVICE_ROLE_KEY=... node scripts/backfill-look-photos.mjs [slug]
//
// With no slug, every published look is checked. A slug limits the run to that page.

const URL = process.env.SUPABASE_URL || "https://yjjdzugecimjwgwtkwyw.supabase.co";
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || "";
const ONLY = process.argv[2] || "";

const NAMES = {
  "b9323fe3-ae72-4919-a05e-f80eeef66c44": "Sundays Are for the Birds sweatshirt",
  "0b0daa8a-e981-4923-8f7a-54deb0ed228d": "Black half-snap stand-collar pullover",
};
const FULL = {
  "b9323fe3-ae72-4919-a05e-f80eeef66c44": "Black Sundays Are for the Birds graphic crewneck sweatshirt",
  "0b0daa8a-e981-4923-8f7a-54deb0ed228d": "Black oversized half-snap stand-collar pullover",
};
const PLACEHOLDER = /^(tops?|bottoms?|shoes?|accessor(y|ies)|dress(es)?|outerwear|bags?|jewel(le)?ry|item|one-pieces?|accessory)$/i;

if (!KEY) {
  console.error("SUPABASE_SERVICE_ROLE_KEY is required. The anon key cannot read studio or update shop_pages.");
  process.exit(1);
}

const headers = { apikey: KEY, Authorization: "Bearer " + KEY };

async function rest(path, opts = {}) {
  const res = await fetch(URL + path, { ...opts, headers: { ...headers, ...(opts.headers || {}) } });
  const text = await res.text();
  let body = null;
  try { body = text ? JSON.parse(text) : null; } catch { body = text; }
  if (!res.ok) throw new Error(res.status + " " + path + " " + (typeof body === "string" ? body : JSON.stringify(body)));
  return body;
}

function photoSources(g) {
  return [g.cutout_path, g.thumb_path, g.path].filter(Boolean);
}

async function downloadStudio(path) {
  const res = await fetch(URL + "/storage/v1/object/studio/" + path.split("/").map(encodeURIComponent).join("/"), { headers });
  if (!res.ok) return null;
  const buf = Buffer.from(await res.arrayBuffer());
  return buf.length ? { buf, type: res.headers.get("content-type") || "" } : null;
}

async function uploadShop(path, buf, type) {
  const res = await fetch(URL + "/storage/v1/object/shop/" + path.split("/").map(encodeURIComponent).join("/"), {
    method: "POST",
    headers: { ...headers, "Content-Type": type || "image/jpeg", "x-upsert": "true" },
    body: buf,
  });
  if (!res.ok) throw new Error("upload " + path + " " + res.status + " " + await res.text());
}

async function main() {
  const filter = ONLY ? "&slug=eq." + encodeURIComponent(ONLY) : "";
  const pages = await rest("/rest/v1/shop_pages?select=id,user_id,slug,items,published&published=eq.true" + filter);
  let copied = 0, named = 0, pagesTouched = 0;
  for (const page of pages) {
    const items = Array.isArray(page.items) ? page.items.map((it) => ({ ...it })) : [];
    let changed = false;
    for (let i = 0; i < items.length; i++) {
      const it = items[i];
      if (!it?.garment_id) continue;
      const rows = await rest("/rest/v1/garments?id=eq." + it.garment_id + "&select=id,name,public_ok,cutout_path,thumb_path,path,user_id");
      const g = rows[0];
      if (!g) continue;
      const known = NAMES[g.id];
      const raw = (g.name || "").trim();
      if (known && (!raw || PLACEHOLDER.test(raw))) {
        await rest("/rest/v1/garments?id=eq." + g.id, { method: "PATCH", headers: { "Content-Type": "application/json", Prefer: "return=minimal" }, body: JSON.stringify({ name: known }) });
        g.name = known;
        named++;
      }
      const shown = (it.name || "").trim();
      if (known && (!shown || PLACEHOLDER.test(shown))) {
        it.name = known;
        it.full_name = FULL[g.id] || known;
        changed = true;
      }
      if (it.image_path || it.image_url) { items[i] = it; continue; }
      let saved = null, src = null;
      for (const candidate of photoSources(g)) {
        const file = await downloadStudio(candidate);
        if (!file) continue;
        const png = /\.png$/i.test(candidate) || /png/.test(file.type);
        const dest = `${page.user_id}/${page.slug}/${g.id}.${png ? "png" : "jpg"}`;
        await uploadShop(dest, file.buf, png ? "image/png" : "image/jpeg");
        saved = dest;
        src = candidate;
        break;
      }
      if (!saved) { items[i] = it; continue; }
      it.image_path = saved;
      changed = true;
      copied++;
      if (src !== g.cutout_path && !g.public_ok) {
        await rest("/rest/v1/garments?id=eq." + g.id, { method: "PATCH", headers: { "Content-Type": "application/json", Prefer: "return=minimal" }, body: JSON.stringify({ public_ok: true }) });
      }
      items[i] = it;
    }
    if (!changed) continue;
    await rest("/rest/v1/shop_pages?id=eq." + page.id, {
      method: "PATCH",
      headers: { "Content-Type": "application/json", Prefer: "return=minimal" },
      body: JSON.stringify({ items, updated_at: new Date().toISOString() }),
    });
    pagesTouched++;
    console.log(page.slug, "updated", items.length, "items");
  }
  console.log(JSON.stringify({ pages: pages.length, pagesTouched, copied, named }));
}

main().catch((e) => { console.error(e.message || e); process.exit(1); });
