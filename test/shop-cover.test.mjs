import assert from "node:assert/strict";
import { test } from "node:test";
import { createServer } from "node:http";
import { readFileSync } from "node:fs";
import { mkdir, writeFile } from "node:fs/promises";
import { extname, join } from "node:path";
import vm from "node:vm";
import puppeteer from "puppeteer-core";

const coverSrc = readFileSync(new URL("../shop-cover.js", import.meta.url), "utf8");
const coverCtx = {};
vm.runInNewContext(coverSrc + "\nthis.shopTilePath = shopTilePath;", coverCtx);
const shopTilePath = coverCtx.shopTilePath;

test("link.amazon and other Amazon short domains count as shoppable links", () => {
  const ctx = { URL };
  vm.runInNewContext(coverSrc + "\nObject.assign(this, { isAmazonLink, isShopLink, shopButtonLabel, affiliateDisclosure });", ctx);
  const ok = ctx.isAmazonLink;
  assert.equal(ok("https://link.amazon/B0d5OQIHy"), true);
  assert.equal(ok("https://link.amazon/B0ik3bCoR"), true);
  assert.equal(ok("https://amzn.to/3abc"), true);
  assert.equal(ok("https://amzn.eu/d/abc"), true);
  assert.equal(ok("https://amzlink.to/abc"), true);
  assert.equal(ok("https://www.amazon.com/dp/B00BAG1234?tag=heather-20"), true);
  assert.equal(ok("https://example.com/dp/B00BAG1234"), false);
  assert.equal(ok("http://link.amazon/B0d5OQIHy"), false);
  const shopOk = ctx.isShopLink;
  const cj = "https://www.tkqlhce.com/click-101828062-15466305?url=https%3A%2F%2Fwww.dreampairs.com%2Fproducts%2Fwomens-platform-ankle-snow-boots-sdsb2427w%3Fcolor%3D1919";
  assert.equal(shopOk(cj), true);
  assert.equal(shopOk("https://www.dreampairs.com/products/boot"), true);
  assert.equal(shopOk("https://example.com/products/boot"), false);
  assert.equal(shopOk("https://tkqlhce.com.evil.com/click"), false);
  assert.equal(shopOk("https://evil.sjv.io/c/1"), true);
  assert.equal(ctx.shopButtonLabel(cj, "Dream Pairs"), "Shop at Dream Pairs");
  assert.equal(ctx.shopButtonLabel("https://www.amazon.com/dp/B00BAG1234", "Dream Pairs"), "Shop on Amazon");
  assert.equal(ctx.shopButtonLabel(cj, ""), "Shop now");
  assert.equal(ctx.affiliateDisclosure("As an Amazon Associate I earn from qualifying purchases.", true), "As an Amazon Associate I earn from qualifying purchases. I may earn a commission from other affiliate links.");
  assert.equal(ctx.affiliateDisclosure("As an Amazon Associate I earn from qualifying purchases.", false), "As an Amazon Associate I earn from qualifying purchases.");
  const shop = readFileSync(new URL("../shop.html", import.meta.url), "utf8");
  const index = readFileSync(new URL("../index.html", import.meta.url), "utf8");
  assert.match(shop, /const ok = \(u\) => isShopLink\(u\)/);
  assert.match(index, /const amazonLink = \(u\) => isShopLink\(u\)/);
  assert.match(index, /isAmazonHost\(host\)/);
});

test("tile image matches the public storefront, including custom.jpg with an empty or collage cover", () => {
  // Cozy Espresso and Olive & On the Go, after Cover: collage rewrote cover_public_path
  // to the auto grid while leaving the styled photo in collage_public_path.
  assert.equal(shopTilePath({
    cover_source: "collage",
    cover_public_path: "u/jsoubro5fr/collage.jpg",
    collage_public_path: "u/jsoubro5fr/custom.jpg",
  }), "u/jsoubro5fr/custom.jpg");
  assert.equal(shopTilePath({
    cover_source: "collage",
    cover_public_path: "u/hyzzf1gkg9/collage.jpg",
    collage_public_path: "u/hyzzf1gkg9/custom.jpg",
  }), "u/hyzzf1gkg9/custom.jpg");
  // Olive before that rewrite: cover path empty, hero is custom.jpg.
  assert.equal(shopTilePath({
    cover_source: "photo",
    cover_public_path: null,
    collage_public_path: "u/hyzzf1gkg9/custom.jpg",
  }), "u/hyzzf1gkg9/custom.jpg");
  assert.equal(shopTilePath({
    cover_public_path: "",
    collage_public_path: "u/hyzzf1gkg9/custom.jpg",
  }), "u/hyzzf1gkg9/custom.jpg");
  // An AI cover.jpg still wins over a custom hero. Both paths already custom stay custom.
  assert.equal(shopTilePath({
    cover_public_path: "u/x/cover.jpg",
    collage_public_path: "u/x/custom.jpg",
  }), "u/x/cover.jpg");
  assert.equal(shopTilePath({
    cover_public_path: "u/x/custom.jpg",
    collage_public_path: "u/x/custom.jpg",
  }), "u/x/custom.jpg");
  assert.equal(shopTilePath({
    cover_public_path: "u/x/collage.png",
    collage_public_path: "u/x/collage.png",
  }), "u/x/collage.png");
  assert.equal(shopTilePath({ cover_public_path: null, collage_public_path: null }), "");
});

test("the editor and the public shop share one tile rule and offer Change photo", () => {
  const index = readFileSync(new URL("../index.html", import.meta.url), "utf8");
  const shop = readFileSync(new URL("../shop.html", import.meta.url), "utf8");
  assert.match(index, /src="shop-cover\.js\?v=/);
  assert.match(shop, /src="shop-cover\.js\?v=/);
  assert.match(shop, /shopTilePath\(r\)/);
  assert.doesNotMatch(shop, /const tilePath/);
  assert.match(index, /shopTilePath\(p\)/);
  assert.match(index, /data-cover="custom">Custom photo/);
  assert.match(index, /data-act="photo">Change photo/);
  assert.match(index, /Upload from camera roll/);
  assert.match(index, /Use the auto collage/);
});

const TYPES = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css" };

function startServer() {
  const server = createServer(async (req, res) => {
    const url = new URL(req.url, "http://127.0.0.1");
    const file = url.pathname === "/" ? "/index.html" : url.pathname;
    try {
      const body = readFileSync(join(process.cwd(), file));
      res.writeHead(200, { "content-type": TYPES[extname(file)] || "application/octet-stream" });
      res.end(body);
    } catch {
      res.writeHead(404);
      res.end("missing");
    }
  });
  return new Promise((resolve) => server.listen(0, "127.0.0.1", () => resolve(server)));
}

test("home-screen storefront shows Studio and reloads when the build changes", async () => {
  const server = await startServer();
  const port = server.address().port;
  const browser = await puppeteer.launch({
    executablePath: "/usr/local/bin/google-chrome",
    headless: true,
    args: ["--no-sandbox", "--disable-dev-shm-usage"],
  });
  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 390, height: 844, isMobile: true, hasTouch: true, deviceScaleFactor: 2 });
    await page.goto(`http://127.0.0.1:${port}/shop.html`, { waitUntil: "networkidle0" });
    await page.waitForFunction(() => document.querySelector("h1"));
    assert.equal(await page.$(".shop-top"), null);

    const stand = await browser.newPage();
    await stand.setViewport({ width: 390, height: 844, isMobile: true, hasTouch: true, deviceScaleFactor: 2 });
    await stand.evaluateOnNewDocument(() => {
      const real = window.matchMedia.bind(window);
      window.matchMedia = (q) => String(q).includes("display-mode: standalone")
        ? { matches: true, media: q, addListener() {}, removeListener() {}, addEventListener() {}, removeEventListener() {}, dispatchEvent() { return false; } }
        : real(q);
      try { Object.defineProperty(navigator, "standalone", { configurable: true, get: () => true }); } catch {}
    });
    await stand.goto(`http://127.0.0.1:${port}/shop.html`, { waitUntil: "networkidle0" });
    await stand.waitForSelector("a.topbtn");
    const homeBtn = await stand.$eval("a.topbtn", (a) => ({ text: a.textContent.trim(), href: a.getAttribute("href"), left: a.getBoundingClientRect().left, h: a.getBoundingClientRect().height }));
    assert.equal(homeBtn.text, "‹ Studio");
    assert.match(homeBtn.href, /index\.html\?v=7$/);
    assert.ok(homeBtn.left < 24);
    assert.ok(homeBtn.h >= 44);
    await mkdir("/opt/cursor/artifacts", { recursive: true });
    await stand.screenshot({ path: "/opt/cursor/artifacts/shop-standalone-home.png" });

    await stand.goto(`http://127.0.0.1:${port}/shop.html?o=9jm0wt9qy6`, { waitUntil: "networkidle0" });
    await stand.waitForSelector("a.topbtn");
    const lookBtns = await stand.$$eval("a.topbtn", (els) => els.map((a) => ({ text: a.textContent.trim(), left: Math.round(a.getBoundingClientRect().left) })));
    assert.equal(lookBtns[0].text, "‹ All looks");
    assert.ok(lookBtns[0].left < 24);
    assert.equal(lookBtns.some((b) => b.text === "‹ Studio"), true);
    await stand.screenshot({ path: "/opt/cursor/artifacts/shop-standalone-look.png" });
    await stand.close();

    const bump = await browser.newPage();
    await bump.setRequestInterception(true);
    bump.on("request", (req) => {
      if (req.url().includes("version.json")) req.respond({ status: 200, contentType: "application/json", body: JSON.stringify({ version: "8" }) });
      else req.continue();
    });
    await bump.goto(`http://127.0.0.1:${port}/shop.html?o=9jm0wt9qy6`, { waitUntil: "domcontentloaded" });
    await bump.waitForFunction(() => new URLSearchParams(location.search).get("v") === "8" && new URLSearchParams(location.search).get("o") === "9jm0wt9qy6");
    await new Promise((r) => setTimeout(r, 400));
    assert.equal(new URL(bump.url()).searchParams.get("v"), "8");
    await bump.close();
  } finally {
    await browser.close();
    await new Promise((resolve) => server.close(resolve));
  }
});

test("storefront editor on a phone shows the live cover and can change it", async () => {
  const server = await startServer();
  const port = server.address().port;
  const browser = await puppeteer.launch({
    executablePath: "/usr/local/bin/google-chrome",
    headless: true,
    args: ["--no-sandbox", "--disable-dev-shm-usage"],
  });
  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
    page.on("dialog", (d) => d.accept());
    await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "networkidle0" });
    await page.waitForFunction(() => window.__studio && window.shopTilePath);

    const images = await page.evaluate(async () => {
      const paint = (w, h, color, label) => new Promise((resolve) => {
        const c = document.createElement("canvas");
        c.width = w; c.height = h;
        const g = c.getContext("2d");
        g.fillStyle = color; g.fillRect(0, 0, w, h);
        g.fillStyle = "#fff"; g.font = "bold 20px sans-serif"; g.fillText(label, 6, h / 2);
        c.toBlob(async (blob) => resolve([...new Uint8Array(await blob.arrayBuffer())]), "image/jpeg", 0.9);
      });
      return {
        photo: await paint(90, 120, "#3b6d47", "PHOTO"),
        grid: await paint(40, 40, "#a1352c", "GRID"),
        ai: await paint(70, 90, "#1d4e89", "AI"),
        shot: await paint(120, 160, "#a8894f", "NEW"),
      };
    });
    const photo = Buffer.from(images.photo);
    const grid = Buffer.from(images.grid);
    const ai = Buffer.from(images.ai);
    await writeFile("/tmp/new-cover.jpg", Buffer.from(images.shot));
    await page.setRequestInterception(true);
    page.on("request", (req) => {
      const u = req.url();
      const cors = { "access-control-allow-origin": "*", "content-type": "image/jpeg" };
      if (u.includes("files.test")) req.respond({ status: 200, contentType: "image/jpeg", headers: cors, body: photo });
      else if (u.includes("custom.jpg")) req.respond({ status: 200, contentType: "image/jpeg", headers: cors, body: photo });
      else if (u.includes("collage.jpg")) req.respond({ status: 200, contentType: "image/jpeg", headers: cors, body: grid });
      else if (u.includes("cover.jpg")) req.respond({ status: 200, contentType: "image/jpeg", headers: cors, body: ai });
      else req.continue().catch(() => {});
    });

    await page.evaluate(() => {
      const s = window.__studio.state;
      s.uid = "user-1";
      s.me = { presets: {}, used_today: 0, daily_cap: 20, email: "heather@example.com", tz: "America/Chicago", actions: {} };
      s.garments = [
        { id: "g-bag", name: "Black tote", brand: "", affiliate_url: "https://www.amazon.com/dp/B00BAG1234?tag=heather-20", asin: "B00BAG1234", path: "studio/bag.jpg", cutout_path: "studio/bag.jpg", category: "bag" },
        { id: "g-ear", name: "", brand: "Mejuri", category: "accessory", notes: "gold earrings", affiliate_url: "https://www.amazon.com/dp/B00EAR1234?tag=heather-20", path: "studio/ear.jpg" },
        { id: "g-belt", name: "Plain belt", brand: "", category: "accessory", affiliate_url: "", product_url: "", path: "studio/belt.jpg" },
        { id: "b9323fe3-ae72-4919-a05e-f80eeef66c44", name: "", brand: "", category: "tops", public_ok: false, path: "studio/birds.jpg", thumb_path: "studio/birds_t.jpg", affiliate_url: "https://link.amazon/B08MpMakT" },
        { id: "0b0daa8a-e981-4923-8f7a-54deb0ed228d", name: "", brand: "", category: "tops", public_ok: false, path: "studio/pullover.jpg", thumb_path: "studio/pullover_t.jpg", affiliate_url: "https://link.amazon/B0apmOD9A" },
      ];
      s.outfits = [{ id: "o-cozy", name: "Cozy Espresso", items: [], hero_generation_id: null }];
      s.generations = [{ id: "gen-1", path: "studio/gen-1.jpg", outfit_id: "o-cozy", created_at: "2026-10-01T00:00:00Z" }];
      s.collages = [
        { id: "c-cozy", name: "Cozy collage", outfit_id: "o-cozy", preview_path: "studio/cozy-preview.jpg", layout: { size: "portrait", bg: "#efe6d9", layers: [] } },
        { id: "c-olive", name: "Olive collage", preview_path: "studio/olive-preview.jpg", layout: { size: "portrait", bg: "#d7d2c8", layers: [] } },
      ];
      s.shops = [
        {
          id: "cozy", slug: "jsoubro5fr", title: "Cozy Espresso — Shop the Look", published: true, listed: true,
          cover_source: "collage", cover_public_path: "user-1/jsoubro5fr/collage.jpg",
          collage_public_path: "user-1/jsoubro5fr/custom.jpg", collage_id: "c-cozy", outfit_id: "o-cozy",
          category: null, featured: false, sort_order: 0, updated_at: "2026-11-02T20:45:11.078Z",
        },
        {
          id: "olive", slug: "hyzzf1gkg9", title: "Olive & On the Go", published: true, listed: true,
          cover_source: "collage", cover_public_path: "user-1/hyzzf1gkg9/collage.jpg",
          collage_public_path: "user-1/hyzzf1gkg9/custom.jpg", collage_id: "c-olive", outfit_id: null,
          category: null, featured: false, sort_order: 0, updated_at: "2026-11-02T20:45:08.066Z",
          items: [
            { garment_id: "g-old", name: "Olive leggings", full_name: "Olive leggings", url: "https://www.amazon.com/dp/B00LEG1234?tag=heather-20", brand: "" },
            { garment_id: "b9323fe3-ae72-4919-a05e-f80eeef66c44", name: "Tops", full_name: "Tops", url: "https://link.amazon/B08MpMakT", brand: "", image_path: null },
            { garment_id: "0b0daa8a-e981-4923-8f7a-54deb0ed228d", name: "Tops", full_name: "Tops", url: "https://link.amazon/B0apmOD9A", brand: "", image_path: null },
          ],
        },
      ];
      s.products = []; s.site = null; s.settings = { amazon_tag: "heather-20" }; s.fbPosts = []; s.reels = []; s._outfitItems = [];
      document.getElementById("login").classList.add("hidden");
      document.getElementById("app").classList.remove("hidden");
      document.getElementById("nav").classList.remove("hidden");
      window.__studio.shopCalls = [];
      const sb = window.__studio.sb;
      const storageApi = () => ({
        upload: async (path, blob, opts) => {
          window.__studio.shopCalls.push({ op: "upload", path, type: blob && blob.type, size: blob && blob.size, upsert: !!(opts && opts.upsert) });
          return { error: null };
        },
        remove: async (paths) => { window.__studio.shopCalls.push({ op: "remove", paths }); return { error: null }; },
        list: async (prefix) => { window.__studio.shopCalls.push({ op: "list", prefix }); return { data: [{ name: "custom.jpg" }, { name: "collage.jpg" }], error: null }; },
        createSignedUrl: async (path) => ({ data: { signedUrl: "https://files.test/" + path }, error: null }),
      });
      Object.defineProperty(sb, "storage", { configurable: true, get: () => ({ from: () => storageApi() }) });
      sb.from = (table) => {
        const q = {
          select() { return q; }, order() { return q; }, range() { return q; },
          update(patch) { q._patch = patch; return q; },
          insert() { return q; },
          eq(col, val) {
            if (col === "id" && q._patch && table === "shop_pages") {
              const row = window.__studio.state.shops.find((s) => s.id === val);
              if (row) Object.assign(row, q._patch);
              window.__studio.shopCalls.push({ op: "update", table, id: val, patch: { ...q._patch } });
            }
            if (col === "id" && q._patch && table === "garments") {
              const row = window.__studio.state.garments.find((g) => g.id === val);
              if (row) Object.assign(row, q._patch);
              window.__studio.shopCalls.push({ op: "update", table, id: val, patch: { ...q._patch } });
            }
            return q;
          },
          maybeSingle() { q._one = true; return q; },
          then(resolve, reject) {
            const state = window.__studio.state;
            const map = {
              selfies: state.selfies || [], models: state.models || [], garments: state.garments || [],
              generations: state.generations || [], outfits: state.outfits || [], outfit_items: state._outfitItems || [],
              collages: state.collages || [], shop_pages: state.shops || [],
              studio_settings: state.settings || {}, shop_products: state.products || [],
              shop_site: state.site || null, fb_posts: state.fbPosts || [], reels: state.reels || [],
            };
            let data = map[table];
            if (q._one) data = table === "shop_site" ? (state.site || null) : table === "studio_settings" ? (state.settings || {}) : (Array.isArray(data) ? data[0] || null : data || null);
            else if (!Array.isArray(data)) data = [];
            return Promise.resolve({ data, error: null }).then(resolve, reject);
          },
        };
        return q;
      };
      window.__studio.shopHomeSheet("looks");
    });

    await page.waitForFunction(() => {
      const img = document.querySelector('[data-sp="cozy"] .tile img');
      return img && img.complete && img.naturalWidth === 90 && img.src.includes("custom.jpg");
    });
    const olive = await page.$eval('[data-sp="olive"] .tile img', (img) => ({ src: img.src, w: img.naturalWidth }));
    assert.match(olive.src, /hyzzf1gkg9\/custom\.jpg/);
    assert.equal(olive.w, 90);
    const chips = async (id) => page.$eval(`[data-sp="${id}"]`, (card) => ({
      custom: card.querySelector('[data-cover="custom"]').classList.contains("on"),
      collage: card.querySelector('[data-cover="collage"]').classList.contains("on"),
      photo: card.querySelector('[data-cover="photo"]').classList.contains("on"),
      aiDisabled: card.querySelector('[data-cover="photo"]').disabled,
      aiText: card.querySelector('[data-cover="photo"]').textContent,
    }));
    assert.deepEqual(await chips("cozy"), { custom: true, collage: false, photo: false, aiDisabled: true, aiText: "Cover: AI photo (none set)" });
    assert.deepEqual(await chips("olive"), { custom: true, collage: false, photo: false, aiDisabled: true, aiText: "Cover: AI photo (none set)" });
    const change = await page.$eval('[data-sp="cozy"] [data-act="photo"]', (el) => {
      const r = el.getBoundingClientRect();
      return { text: el.textContent, h: r.height, w: r.width };
    });
    assert.equal(change.text, "Change photo");
    assert.ok(change.h >= 44, `change photo tap target ${change.h}px`);
    assert.ok(change.w >= 140, `change photo width ${change.w}px`);

    await mkdir("/opt/cursor/artifacts", { recursive: true });
    await page.$eval('[data-sp="cozy"]', (el) => el.scrollIntoView({ block: "start" }));
    await page.screenshot({ path: "/opt/cursor/artifacts/storefront-editor-phone.png" });

    await page.click('[data-sp="olive"] [data-act="photo"]');
    await page.waitForSelector("#cpUpload");
    const sheet = await page.evaluate(() => ({
      upload: document.getElementById("cpUpload").textContent,
      uploadH: document.getElementById("cpUpload").getBoundingClientRect().height,
      photos: document.querySelectorAll("#cpPhotos .tile").length,
      collages: document.querySelectorAll("#cpCollages .tile").length,
      revert: document.getElementById("cpRevert").textContent,
      accept: document.getElementById("cpFile").accept,
    }));
    assert.equal(sheet.upload, "Upload from camera roll");
    assert.ok(sheet.uploadH >= 44);
    assert.equal(sheet.photos, 1);
    assert.equal(sheet.collages, 2);
    assert.equal(sheet.revert, "Use the auto collage");
    assert.match(sheet.accept, /image/);
    await page.screenshot({ path: "/opt/cursor/artifacts/change-photo-phone.png" });

    await page.waitForFunction(() => {
      const img = document.querySelector("#cpPhotos img");
      return img && img.complete && img.naturalWidth === 90;
    });
    page.on("pageerror", (err) => console.error("PAGEERROR", err.message));
    await page.click("#cpPhotos .tile");
    await page.waitForFunction(() => !document.getElementById("adjuster").classList.contains("hidden") && document.querySelector("#adjAspect [data-a='4:5']").classList.contains("on"));
    await page.click("#adjRot");
    await page.screenshot({ path: "/opt/cursor/artifacts/adjust-photo-phone.png" });
    await page.click("#adjSave");
    try {
      await page.waitForFunction(() => (document.getElementById("shhMsg")?.textContent || "").includes("Photo updated"), { timeout: 8000 });
    } catch (e) {
      const info = await page.evaluate(() => ({
        cp: document.getElementById("cpMsg")?.textContent || "",
        shh: document.getElementById("shhMsg")?.textContent || "",
        calls: window.__studio.shopCalls,
      }));
      throw new Error(e.message + " " + JSON.stringify(info));
    }
    const saved = await page.evaluate(() => window.__studio.shopCalls.filter((c) => c.op === "upload" || c.op === "update"));
    const upload = saved.find((c) => c.op === "upload" && c.path.endsWith("/custom.jpg"));
    assert.ok(upload);
    assert.equal(upload.path, "user-1/hyzzf1gkg9/custom.jpg");
    assert.equal(upload.type, "image/jpeg");
    assert.equal(upload.upsert, true);
    const patch = saved.filter((c) => c.op === "update").at(-1).patch;
    assert.equal(patch.collage_public_path, "user-1/hyzzf1gkg9/custom.jpg");
    assert.equal(patch.cover_public_path, "user-1/hyzzf1gkg9/custom.jpg");
    assert.equal(await chips("olive").then((c) => c.custom), true);
    await page.waitForFunction(() => {
      const img = document.querySelector('[data-sp="olive"] .tile img');
      return img && img.complete && img.naturalWidth === 90;
    });

    await page.click('[data-sp="cozy"] [data-act="photo"]');
    await page.waitForSelector("#cpFile");
    const chooser = await page.$("#cpFile");
    await chooser.uploadFile("/tmp/new-cover.jpg");
    await page.waitForFunction(() => !document.getElementById("adjuster").classList.contains("hidden"));
    await page.click("#adjSave");
    await page.waitForFunction(() => (document.getElementById("shhMsg")?.textContent || "").includes("Photo updated"));
    const fileUpload = (await page.evaluate(() => window.__studio.shopCalls)).filter((c) => c.op === "upload").at(-1);
    assert.equal(fileUpload.path, "user-1/jsoubro5fr/custom.jpg");
    assert.equal(fileUpload.type, "image/jpeg");

    await page.click('[data-sp="cozy"] [data-cover="collage"]');
    await page.waitForFunction(() => (document.getElementById("shhMsg")?.textContent || "").includes("auto collage"));
    const afterCollage = await page.$eval('[data-sp="cozy"] .tile img', (img) => img.src);
    assert.match(afterCollage, /jsoubro5fr\/collage\.jpg/);
    assert.equal((await chips("cozy")).collage, true);
    assert.equal((await chips("cozy")).custom, false);
    const removed = (await page.evaluate(() => window.__studio.shopCalls)).filter((c) => c.op === "remove");
    assert.equal(removed.length, 0);

    await page.click('[data-sp="cozy"] [data-cover="custom"]');
    await page.waitForFunction(() => {
      const img = document.querySelector('[data-sp="cozy"] .tile img');
      const msg = document.getElementById("shhMsg")?.textContent || "";
      return msg.includes("Custom photo") && img && img.complete && img.naturalWidth === 90 && img.src.includes("custom.jpg");
    });
    assert.equal((await chips("cozy")).custom, true);

    await page.screenshot({ path: "/opt/cursor/artifacts/storefront-editor-after-change.png" });

    const kept = await page.evaluate(() => window.__studio.withManualShopItems(
      [{ garment_id: "g1", name: "Tee", url: "https://www.amazon.com/dp/B000000001?tag=heather-20" }],
      [{ manual: true, name: "Gold hoops", url: "https://www.amazon.com/dp/B0TEST1234?tag=heather-20" }],
    ));
    assert.equal(kept.length, 2);
    assert.equal(kept[1].name, "Gold hoops");

    await page.click('[data-sp="olive"] [data-act="items"]');
    await page.waitForSelector("#liAdd");
    assert.match(await page.$eval("#sheetBody h3", (el) => el.textContent), /Items/);
    assert.match(await page.$eval("#liList", (el) => el.textContent), /Olive leggings/);
    const addH = await page.$eval("#liAdd", (el) => el.getBoundingClientRect().height);
    assert.ok(addH >= 44);
    const choiceIds = await page.evaluate(() => window.__studio.closetChoices(window.__studio.state.garments, []).map((g) => g.id));
    assert.deepEqual(choiceIds.filter((id) => id === "g-ear" || id === "g-belt").sort(), ["g-belt", "g-ear"]);
    await page.click("#liSearch");
    await page.waitForSelector("#csSearch");
    await page.type("#csSearch", "earring");
    await page.click("#csCats [data-cat='accessory']");
    await page.waitForFunction(() => document.querySelector("#csList [data-add='g-ear']"));
    assert.equal(await page.$eval("#csList", (el) => el.textContent.includes("Plain belt")), false);
    await page.click("#csList [data-add='g-ear']");
    await page.waitForFunction(() => (document.getElementById("liMsg")?.textContent || "").includes("saved Amazon link"));
    const earPatch = (await page.evaluate(() => window.__studio.shopCalls.filter((c) => c.op === "update" && c.table === "shop_pages"))).at(-1).patch;
    const earItem = earPatch.items.find((it) => it.garment_id === "g-ear");
    assert.equal(earItem.url, "https://www.amazon.com/dp/B00EAR1234?tag=heather-20");
    assert.equal(earItem.name.length > 0, true);
    assert.equal(earItem.image_path, "user-1/hyzzf1gkg9/g-ear.jpg");
    assert.deepEqual(earPatch.items.map((it) => it.garment_id), ["g-old", "b9323fe3-ae72-4919-a05e-f80eeef66c44", "0b0daa8a-e981-4923-8f7a-54deb0ed228d", "g-ear"]);
    const birds = earPatch.items[1];
    const pullover = earPatch.items[2];
    assert.equal(birds.name, "Sundays Are for the Birds sweatshirt");
    assert.equal(birds.image_path, "user-1/hyzzf1gkg9/b9323fe3-ae72-4919-a05e-f80eeef66c44.jpg");
    assert.equal(pullover.name, "Black half-snap stand-collar pullover");
    assert.equal(pullover.image_path, "user-1/hyzzf1gkg9/0b0daa8a-e981-4923-8f7a-54deb0ed228d.jpg");
    const published = await page.evaluate(() => ({
      birds: window.__studio.state.garments.find((g) => g.id === "b9323fe3-ae72-4919-a05e-f80eeef66c44"),
      pullover: window.__studio.state.garments.find((g) => g.id === "0b0daa8a-e981-4923-8f7a-54deb0ed228d"),
      uploads: window.__studio.shopCalls.filter((c) => c.op === "upload").map((c) => c.path),
    }));
    assert.equal(published.birds.public_ok, true);
    assert.equal(published.birds.name, "Sundays Are for the Birds sweatshirt");
    assert.equal(published.pullover.public_ok, true);
    assert.equal(published.uploads.includes("user-1/hyzzf1gkg9/b9323fe3-ae72-4919-a05e-f80eeef66c44.jpg"), true);
    assert.equal(published.uploads.includes("user-1/hyzzf1gkg9/0b0daa8a-e981-4923-8f7a-54deb0ed228d.jpg"), true);
    await page.screenshot({ path: "/opt/cursor/artifacts/search-closet-phone.png" });

    await page.click('#liPick [data-add="g-bag"]');
    await page.waitForFunction(() => (document.getElementById("liMsg")?.textContent || "").includes("saved Amazon link"));
    assert.match(await page.$eval("#liList", (el) => el.textContent), /Black tote/);
    const addedItems = (await page.evaluate(() => window.__studio.shopCalls.filter((c) => c.op === "update"))).at(-1).patch.items;
    assert.equal(addedItems.some((it) => it.garment_id === "g-bag" && it.url.includes("tag=heather-20")), true);
    assert.equal(addedItems.some((it) => it.garment_id === "g-old"), true);

    await page.click('#liList [data-rm="0"]');
    await page.waitForFunction(() => (document.getElementById("liMsg")?.textContent || "").includes("Removed"));
    assert.equal(await page.$eval("#liList", (el) => el.textContent.includes("Olive leggings")), false);

    await page.$eval("#liUrl", (el) => { el.value = "https://www.amazon.com/dp/B0TEST1234"; el.dispatchEvent(new Event("input", { bubbles: true })); });
    await page.type("#liName", "Gold hoops");
    await page.click('#liPick [data-add="g-belt"]');
    await page.waitForSelector("#liItemUrl");
    assert.equal(await page.$eval("#liSaveBack", (el) => el.checked), true);
    await page.$eval("#liItemUrl", (el) => { el.value = "https://www.amazon.com/dp/B00BELT123"; });
    await page.click("#liItemAdd");
    await page.waitForFunction(() => /Added/.test(document.getElementById("liMsg")?.textContent || ""));
    const beltSaved = (await page.evaluate(() => window.__studio.shopCalls.filter((c) => c.table === "garments" && c.patch && c.patch.affiliate_url))).at(-1);
    assert.equal(beltSaved.patch.affiliate_url, "https://www.amazon.com/dp/B00BELT123?tag=heather-20");

    await page.$eval("#liUrl", (el) => { el.value = "https://link.amazon/B0d5OQIHy"; el.dispatchEvent(new Event("input", { bubbles: true })); });
    await page.$eval("#liName", (el) => { el.value = "Gold hoops"; });
    await page.click("#liAdd");
    await page.waitForFunction(() => /Short link kept/.test(document.getElementById("liMsg")?.textContent || ""));
    const linked = (await page.evaluate(() => window.__studio.shopCalls.filter((c) => c.op === "update"))).at(-1).patch.items;
    const hoops = linked.find((it) => it.manual);
    assert.equal(hoops.name, "Gold hoops");
    assert.equal(hoops.url, "https://link.amazon/B0d5OQIHy");
    await page.screenshot({ path: "/opt/cursor/artifacts/edit-items-phone.png" });

    await page.goto(`http://127.0.0.1:${port}/shop.html`, { waitUntil: "domcontentloaded" });
    const linkOk = await page.evaluate(() => isAmazonLink("https://link.amazon/B0d5OQIHy") && !isAmazonLink("https://example.com/x"));
    assert.equal(linkOk, true);
    const fromShop = await page.evaluate(() => shopTilePath({
      cover_source: "collage",
      cover_public_path: "u/hyzzf1gkg9/collage.jpg",
      collage_public_path: "u/hyzzf1gkg9/custom.jpg",
    }));
    assert.equal(fromShop, "u/hyzzf1gkg9/custom.jpg");
  } finally {
    await browser.close();
    await new Promise((resolve) => server.close(resolve));
  }
});
