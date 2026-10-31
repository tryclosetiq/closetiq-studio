import assert from "node:assert/strict";
import { test } from "node:test";
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { mkdir } from "node:fs/promises";
import { extname, join } from "node:path";
import puppeteer from "puppeteer-core";

const TYPES = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css" };

function startServer() {
  const server = createServer(async (req, res) => {
    const url = new URL(req.url, "http://127.0.0.1");
    const file = url.pathname === "/" ? "/index.html" : url.pathname;
    try {
      const body = await readFile(join(process.cwd(), file));
      res.writeHead(200, { "content-type": TYPES[extname(file)] || "application/octet-stream" });
      res.end(body);
    } catch {
      res.writeHead(404);
      res.end("missing");
    }
  });
  return new Promise((resolve) => server.listen(0, "127.0.0.1", () => resolve(server)));
}

function sample(page, color, label) {
  return page.evaluate((hex, name) => {
    const c = document.createElement("canvas");
    c.width = 90; c.height = 120;
    const g = c.getContext("2d");
    g.fillStyle = hex; g.fillRect(0, 0, 90, 120);
    g.fillStyle = "#fff"; g.font = "bold 16px sans-serif"; g.fillText(name, 8, 64);
    return c.toDataURL("image/jpeg", 0.8);
  }, color, label);
}

test("try-on multi-select and the outfit sheet render in the real page", async () => {
  const server = await startServer();
  const port = server.address().port;
  const browser = await puppeteer.launch({
    executablePath: "/usr/local/bin/google-chrome",
    headless: true,
    args: ["--no-sandbox", "--disable-dev-shm-usage"],
  });
  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 2 });
    await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "networkidle0" });
    await page.waitForFunction(() => window.__studio);

    const shots = ["#c45c26", "#2f6f4e", "#1d4e89", "#111111"];
    const urls = [];
    for (const [i, color] of shots.entries()) urls.push(await sample(page, color, String(i + 1)));

    await page.evaluate((photos) => {
      const s = window.__studio.state;
      s.me = {
        presets: {
          max_fast_1k: { label: "Fast 1K", credits: 1 },
          max_balanced_1k: { label: "Balanced 1K", credits: 2 },
          max_quality_1k: { label: "Quality 1K", credits: 3 },
        },
        used_today: 1, daily_cap: 20, email: "heather@example.com", tz: "America/Chicago",
        actions: { bgremove: 1, face_reference: 3, model_fast: 1, model_balanced: 2, extract: 1, p2m_fast: 1, p2m_balanced: 2 },
      };
      s.uid = "user-1";
      s.flux = { ok: true, configured: true, credits: 1, max: 4 };
      s.selfies = [{ id: "s1", path: photos[0], thumb_path: photos[0], label: "Heather" }];
      s.models = [];
      s.garments = ["Bomber", "Trousers", "Loafers", "Cap"].map((name, i) => ({
        id: "g" + (i + 1), name, path: photos[i], thumb_path: photos[i], source: "upload", notes: i === 0 ? "oversized" : "",
      }));
      s.outfits = [{ id: "o1", name: "Weekend layers", items: ["g1", "g2", "g3", "g4"], caption: "" }];
      s.sel.selfie = "s1";
      s.sel.engine = "flux";
      document.getElementById("usage").textContent = "1/20 today · 80 left";
      document.getElementById("preset").innerHTML = '<option value="max_balanced_1k">Balanced 1K · 2 credits</option>';
      document.getElementById("login").classList.add("hidden");
      document.getElementById("app").classList.remove("hidden");
      document.getElementById("nav").classList.remove("hidden");
      window.__studio.showTab("tryon");
      window.__studio.setGarmentSelection(["g1"]);
      window.__studio.renderPickers();
    }, urls);

    await page.waitForFunction(() => [...document.querySelectorAll("#pickGarment img")].every((img) => img.complete && img.naturalWidth > 0));
    const single = await page.$eval("#generate", (el) => ({ text: el.textContent, disabled: el.disabled }));
    assert.equal(single.text, "Generate try-on · 1 credit");
    assert.equal(single.disabled, false);
    await page.click("#engineChips [data-engine='fashn']");
    assert.equal(await page.$eval("#generate", (el) => el.textContent), "Generate try-on");
    assert.equal(await page.$eval("#presetWrap", (el) => el.classList.contains("hidden")), false);
    await page.click("#engineChips [data-engine='flux']");

    await page.click("#pickGarment .tile[data-id='g2']");
    await page.click("#pickGarment .tile[data-id='g3']");
    const multi = await page.$eval("#generate", (el) => el.textContent);
    assert.equal(multi, "Try on 3 items · 1 credit");
    const badges = await page.$$eval("#pickGarment .tile.sel .badge", (els) => els.map((el) => el.textContent));
    assert.deepEqual(badges, ["1", "2", "3"]);
    await page.setViewport({ width: 390, height: 1180, deviceScaleFactor: 2 });
    await mkdir("/opt/cursor/artifacts", { recursive: true });
    await page.screenshot({ path: "/opt/cursor/artifacts/tryon-multiselect.png" });

    await page.click("#pickGarment .tile[data-id='g2']");
    assert.equal(await page.$eval("#generate", (el) => el.textContent), "Try on 2 items · 1 credit");
    await page.click("#pickGarment .tile[data-id='g2']");
    assert.equal(await page.$eval("#generate", (el) => el.textContent), "Try on 3 items · 1 credit");

    await page.evaluate(() => {
      const s = window.__studio.state;
      const items = s.outfits[0].items.map((id) => s.garments.find((g) => g.id === id));
      window.__studio.outfitTrySheet(s.outfits[0], items);
    });
    await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 2 });
    await page.waitForFunction(() => document.getElementById("otGo")?.textContent?.includes("Try on 4 items"));
    const method = await page.$eval("[data-m='flux']", (el) => el.classList.contains("on"));
    assert.equal(method, true);
    assert.match(await page.$eval("#otCost", (el) => el.textContent), /1 credit/);
    await page.screenshot({ path: "/opt/cursor/artifacts/outfit-tryon-flux.png" });

    await page.evaluate(() => {
      window.__studio.state.flux = { ok: false, configured: false, credits: 1, max: 4, reason: "missing" };
      window.__studio.setGarmentSelection(["g1", "g2", "g3"]);
      window.__studio.showTab("tryon");
      window.__studio.renderPickers();
    });
    const soon = await page.$eval("#generate", (el) => ({ text: el.textContent, disabled: el.disabled }));
    assert.equal(soon.text, "Try on 3 items · coming soon");
    assert.equal(soon.disabled, true);
    await page.evaluate(() => window.__studio.setGarmentSelection(["g1"]) || window.__studio.renderPickers());
    assert.equal(await page.$eval("#generate", (el) => el.textContent), "Generate try-on");
    assert.equal(await page.$eval("#generate", (el) => el.disabled), false);
    assert.equal(await page.$eval("#engineRow", (el) => el.classList.contains("hidden")), true);
  } finally {
    await browser.close();
    await new Promise((resolve) => server.close(resolve));
  }
});
