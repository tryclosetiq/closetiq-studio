import assert from "node:assert/strict";
import { test } from "node:test";
import { Image } from "imagescript";
import { handleFlux, insertGenerationFallback } from "../supabase/functions/_shared/flux_handler.mjs";

const KEY = "bfl-test-key-should-not-leak";

async function png(width, height, color) {
  const img = new Image(width, height);
  img.fill(color);
  return await img.encode();
}

function ctx(over = {}) {
  const calls = [];
  const inserted = [];
  const removed = [];
  const files = new Map();
  const base = {
    Image,
    calls,
    inserted,
    removed,
    files,
    getEnv(name) { return name === "BFL_API_KEY" ? KEY : ""; },
    async loadSession() { return { userId: "user-1" }; },
    async studioMe() { return { used_today: 2, daily_cap: 20 }; },
    async garments(_userId, ids) {
      return ids.map((id) => ({ id, user_id: "user-1", name: `Item ${id}`, notes: id === "g1" ? "oversized" : "", path: `user-1/garments/${id}.png`, source: "upload" }));
    },
    async personOwned(userId, path) { return userId === "user-1" && path === "user-1/selfies/me.jpg"; },
    async outfitOwned(userId, id) { return userId === "user-1" && id === "outfit-1" ? id : null; },
    async download(path) {
      if (!files.has(path)) throw new Error("missing " + path);
      return files.get(path);
    },
    async upload(path, bytes) { files.set(path, bytes); },
    async remove(path) { removed.push(path); files.delete(path); },
    async insertGeneration(row) { inserted.push(row); },
    sleep: async () => {},
    pollEveryMs: 0,
    pollMs: 5000,
    uuid: () => "gen-1",
    fetch: async (url, opts) => {
      calls.push({ url, opts });
      if (String(url).includes("/vto-v2")) {
        return jsonResponse({ id: "task-1", polling_url: "https://api.bfl.ai/v1/get_result?id=task-1" });
      }
      if (String(url).includes("/get_result")) {
        return jsonResponse({ status: "Ready", result: { sample: "https://delivery.bfl.ai/sample.jpg" } });
      }
      if (String(url).includes("delivery.bfl.ai")) {
        return new Response(await png(8, 8, 0x112233ff), { status: 200 });
      }
      throw new Error("unexpected fetch " + url);
    },
  };
  return Object.assign(base, over);
}

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

function request(body, auth = "Bearer user-jwt-token") {
  return new Request("https://example.test/flux-vto", {
    method: "POST",
    headers: { Authorization: auth, "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

async function seed(deps, ids = ["g1", "g2"]) {
  deps.files.set("user-1/selfies/me.jpg", await png(40, 60, 0xffccaa));
  for (const id of ids) deps.files.set(`user-1/garments/${id}.png`, await png(30, 50, id === "g1" ? 0xff0000ff : 0x00ff00ff));
}

test("probe reports cost and whether the key is set, without calling BFL", async () => {
  const deps = ctx();
  const res = await handleFlux(request({ probe: true }), deps);
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.ok, true);
  assert.equal(body.configured, true);
  assert.equal(body.credits, 1);
  assert.equal(body.max_items, 4);
  assert.equal(deps.calls.length, 0);
  const hidden = ctx({ getEnv: () => "" });
  const off = await (await handleFlux(request({ probe: true }), hidden)).json();
  assert.equal(off.configured, false);
});

test("a two-item run merges a 1024x512 grid, polls BFL, and saves one credit", async () => {
  const deps = ctx();
  await seed(deps);
  const res = await handleFlux(request({
    person_path: "user-1/selfies/me.jpg",
    garment_ids: ["g2", "g1"],
    source: "path",
    instructions: "keep the phone",
    keep_fit: true,
    meta: { outfit_id: "outfit-1" },
  }), deps);
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.credits, 1);
  assert.equal(body.used_today, 3);
  assert.equal(body.daily_cap, 20);
  assert.equal(body.path, "user-1/generations/gen-1.jpg");
  assert.equal(JSON.stringify(body).includes(KEY), false);

  const submit = deps.calls[0];
  assert.equal(submit.url, "https://api.bfl.ai/v1/flux-tools/vto-v2");
  assert.equal(submit.opts.headers["x-key"], KEY);
  const payload = JSON.parse(submit.opts.body);
  assert.match(payload.prompt, /Item g2/);
  assert.match(payload.prompt, /Item g1/);
  assert.match(payload.prompt, /oversized and loose/);
  assert.match(payload.prompt, /keep the phone/);
  const garment = await Image.decode(Buffer.from(payload.garment, "base64"));
  assert.equal(garment.width, 1024);
  assert.equal(garment.height, 512);
  assert.equal(deps.inserted.length, 1);
  assert.equal(deps.inserted[0].credits, 1);
  assert.equal(deps.inserted[0].preset, "flux_vto");
  assert.deepEqual(deps.inserted[0].style.garment_ids, ["g2", "g1"]);
  assert.equal(deps.inserted[0].outfit_id, "outfit-1");
  assert.equal(deps.inserted[0].kind, "outfit_flux");
  assert.ok(deps.files.has("user-1/generations/gen-1.jpg"));
});

test("daily limit, too many items, and a moderated job do not save or charge", async () => {
  const capped = ctx({ studioMe: async () => ({ used_today: 20, daily_cap: 20 }) });
  await seed(capped);
  const limited = await handleFlux(request({ person_path: "user-1/selfies/me.jpg", garment_ids: ["g1"] }), capped);
  assert.equal(limited.status, 402);
  assert.equal(capped.calls.length, 0);
  assert.equal(capped.inserted.length, 0);

  const many = ctx();
  const tooMany = await handleFlux(request({ person_path: "user-1/selfies/me.jpg", garment_ids: ["a", "b", "c", "d", "e"] }), many);
  assert.equal(tooMany.status, 400);
  assert.equal(many.calls.length, 0);

  const moderated = ctx({
    fetch: async (url) => {
      if (String(url).includes("/vto-v2")) return jsonResponse({ id: "t", polling_url: "https://api.bfl.ai/v1/get_result?id=t" });
      return jsonResponse({ status: "Content Moderated" });
    },
  });
  await seed(moderated);
  const blocked = await handleFlux(request({ person_path: "user-1/selfies/me.jpg", garment_ids: ["g1"] }), moderated);
  assert.equal(blocked.status, 502);
  assert.match(await blocked.text(), /not used/);
  assert.equal(moderated.inserted.length, 0);

  const sneaky = ctx({
    fetch: async () => jsonResponse({ id: "t", polling_url: "https://evil.example/v1/get_result?id=t" }),
  });
  await seed(sneaky);
  const rejected = await handleFlux(request({ person_path: "user-1/selfies/me.jpg", garment_ids: ["g1"] }), sneaky);
  assert.equal(rejected.status, 502);
  assert.match(await rejected.text(), /unexpected status URL/);
  assert.equal(sneaky.inserted.length, 0);
});

test("Amazon items and photos the user does not own are refused", async () => {
  const deps = ctx({
    garments: async () => [{ id: "g1", name: "Live listing", source: "amazon_api", path: null }],
  });
  deps.files.set("user-1/selfies/me.jpg", await png(8, 8, 0xffffffff));
  const res = await handleFlux(request({ person_path: "user-1/selfies/me.jpg", garment_ids: ["g1"] }), deps);
  assert.equal(res.status, 400);
  assert.match(await res.text(), /Amazon-API/);

  const stranger = ctx({ personOwned: async () => false });
  const denied = await handleFlux(request({ person_path: "user-1/selfies/me.jpg", garment_ids: ["g1"] }), stranger);
  assert.equal(denied.status, 400);
});

test("unsigned callers are rejected and the key is scrubbed from errors", async () => {
  const res = await handleFlux(request({ probe: true }, ""), ctx());
  assert.equal(res.status, 401);
  const deps = ctx({
    download: async () => { throw new Error("disk said " + KEY); },
  });
  deps.files.set("user-1/selfies/me.jpg", await png(4, 4, 0xffffffff));
  const err = await handleFlux(request({ person_path: "user-1/selfies/me.jpg", garment_ids: ["g1"] }), deps);
  const text = await err.text();
  assert.equal(text.includes(KEY), false);
  assert.match(text, /disk said/);
});

test("generation insert drops unknown columns and then saves", async () => {
  const seen = [];
  const data = await insertGenerationFallback(async (row) => {
    seen.push(Object.keys(row).sort().join(","));
    if ("style" in row) return { ok: false, error: "Could not find the 'style' column of 'generations' in the schema cache" };
    return { ok: true, data: { id: row.id } };
  }, { id: "1", style: { engine: "flux-vto-v2" }, prompt: "hi", kind: "outfit_flux", credits: 1 });
  assert.equal(data.id, "1");
  assert.equal(seen.length >= 2, true);
  assert.equal(seen.at(-1).includes("style"), false);
});
