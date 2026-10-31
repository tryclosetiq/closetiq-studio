import { composeGarmentGrid, preparePerson, bytesToBase64 } from "./compose_grid.mjs";
import { FLUX_STUDIO_CREDITS, fluxPrompt, cleanText } from "./flux_prompt.mjs";
import { MAX_GARMENTS } from "./garment_grid.mjs";

const CORS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
};

function json(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "content-type": "application/json" },
  });
}

function scrub(message, key) {
  const text = String(message || "");
  return key ? text.split(key).join("") : text;
}

export function garmentFile(row, source) {
  if (row.source === "amazon_api") {
    throw new Error(`"${cleanText(row.name) || "This item"}" is an Amazon-API product and can't be used for try-on.`);
  }
  const chosen = source === "cutout" && row.cutout_path ? row.cutout_path : row.path;
  if (!chosen) throw new Error(`"${cleanText(row.name) || "This item"}" has no photo.`);
  return safeStoragePath(chosen);
}

export function safeStoragePath(path) {
  if (typeof path !== "string" || !path || path.includes("..") || path.startsWith("/") || path.includes("://") || path.includes("\\")) {
    throw new Error("Bad photo path.");
  }
  return path;
}

export function orderRows(ids, rows) {
  const byId = new Map((rows || []).map((row) => [row.id, row]));
  return ids.map((id) => byId.get(id)).filter(Boolean);
}

export function allowedPoll(url) {
  try {
    const u = new URL(url);
    return u.protocol === "https:" &&
      ["api.bfl.ai", "api.eu.bfl.ai", "api.us.bfl.ai"].includes(u.hostname) &&
      u.pathname === "/v1/get_result";
  } catch {
    return false;
  }
}

export function allowedResult(url) {
  try {
    const u = new URL(url);
    return u.protocol === "https:" && (u.hostname === "delivery.bfl.ai" || u.hostname.endsWith(".bfl.ai"));
  } catch {
    return false;
  }
}

// Retries without columns the live `generations` table might not have yet.
export async function insertGenerationFallback(insert, row) {
  const noStyle = { ...row };
  delete noStyle.style;
  const minimal = { ...row, kind: "tryon" };
  delete minimal.style;
  delete minimal.prompt;
  const legacy = { ...minimal, kind: "outfit_single" };
  delete legacy.outfit_id;
  const variants = [row, { ...row, kind: "tryon" }, noStyle, minimal, legacy];
  let last = "Could not save the photo.";
  const seen = new Set();
  for (const variant of variants) {
    const key = JSON.stringify(variant);
    if (seen.has(key)) continue;
    seen.add(key);
    const result = await insert(variant);
    if (result?.ok) return result.data;
    last = result?.error || last;
    if (!/style|prompt|kind|outfit_id|preset|check constraint|column|schema cache/i.test(last)) break;
  }
  throw new Error(last);
}

function failure(status, error, key) {
  return json(status, { error: scrub(error, key) });
}

export async function handleFlux(req, deps) {
  const key = deps.getEnv("BFL_API_KEY") || "";
  try {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
    if (req.method !== "POST") return json(405, { error: "POST only." });

    const auth = req.headers.get("authorization") || req.headers.get("Authorization") || "";
    if (!auth.startsWith("Bearer ") || auth.length < 16) return json(401, { error: "Sign in required" });

    let body;
    try { body = await req.json(); }
    catch { return json(400, { error: "Expected JSON." }); }

    const session = await deps.loadSession(auth);
    if (!session?.userId) return json(401, { error: "Sign in required" });

    if (body.probe) {
      return json(200, {
        ok: true,
        configured: !!key,
        engine: "flux-vto-v2",
        credits: FLUX_STUDIO_CREDITS,
        max_items: MAX_GARMENTS,
      });
    }

    if (!key) return json(503, { error: "FLUX isn't configured yet. Set the BFL_API_KEY secret, then deploy flux-vto. Studio credits were not used." });

    const ids = Array.isArray(body.garment_ids) ? body.garment_ids.map((id) => String(id)) : [];
    if (ids.length < 1 || ids.length > MAX_GARMENTS) return json(400, { error: `Pick 1 to ${MAX_GARMENTS} clothing items.` });
    if (new Set(ids).size !== ids.length) return json(400, { error: "Each item can only be included once." });

    let personPath;
    try { personPath = safeStoragePath(String(body.person_path || "")); }
    catch (e) { return json(400, { error: e.message }); }

    const owned = await deps.personOwned(session.userId, personPath);
    if (!owned) return json(400, { error: "That photo isn't in your studio." });

    const rows = orderRows(ids, await deps.garments(session.userId, ids));
    if (rows.length !== ids.length) return json(400, { error: "One of those items isn't in your clothing." });

    const source = body.source === "cutout" ? "cutout" : "path";
    let files;
    try { files = rows.map((row) => garmentFile(row, source)); }
    catch (e) { return json(400, { error: e.message }); }

    const me = await deps.studioMe(auth);
    if (!me || typeof me.used_today !== "number" || typeof me.daily_cap !== "number") {
      return json(503, { error: "Couldn't check today's credit limit. Nothing was generated." });
    }
    if (me.used_today + FLUX_STUDIO_CREDITS > me.daily_cap) {
      return json(402, { error: `Daily limit reached (${me.used_today}/${me.daily_cap}). Nothing was generated.` });
    }

    const garmentBytes = [];
    for (const path of files) garmentBytes.push(await deps.download(path));
    const personBytes = await deps.download(personPath);
    const grid = await composeGarmentGrid(garmentBytes, deps.Image);
    const person = await preparePerson(personBytes, deps.Image);
    const prompt = fluxPrompt(rows, {
      instructions: body.instructions || "",
      keepFit: body.keep_fit !== false,
    });

    const submitRes = await deps.fetch("https://api.bfl.ai/v1/flux-tools/vto-v2", {
      method: "POST",
      headers: { accept: "application/json", "content-type": "application/json", "x-key": key },
      body: JSON.stringify({
        prompt,
        person: bytesToBase64(person),
        garment: bytesToBase64(grid.bytes),
        output_format: "jpeg",
        safety_tolerance: 2,
      }),
    });
    if (!submitRes.ok) return failure(502, `FLUX couldn't start (${submitRes.status}). Studio credits were not used.`, key);

    const submitted = await submitRes.json();
    const pollUrl = submitted.polling_url || `https://api.bfl.ai/v1/get_result?id=${encodeURIComponent(submitted.id || "")}`;
    if (!allowedPoll(pollUrl)) return json(502, { error: "FLUX returned an unexpected status URL. Studio credits were not used." });

    const sleep = deps.sleep || ((ms) => new Promise((resolve) => setTimeout(resolve, ms)));
    const deadline = Date.now() + (deps.pollMs || 50000);
    let sample = "";
    while (Date.now() < deadline) {
      await sleep(deps.pollEveryMs ?? 1000);
      const pollRes = await deps.fetch(pollUrl, { headers: { accept: "application/json", "x-key": key } });
      if (!pollRes.ok) return failure(502, `FLUX status check failed (${pollRes.status}). Studio credits were not used.`, key);
      const poll = await pollRes.json();
      if (poll.status === "Ready") {
        sample = poll.result?.sample || "";
        break;
      }
      if (["Error", "Request Moderated", "Content Moderated", "Task not found"].includes(poll.status)) {
        return json(502, { error: `FLUX ${poll.status}. Studio credits were not used.` });
      }
    }
    if (!sample) return json(504, { error: "FLUX took too long. Studio credits were not used." });
    if (!allowedResult(sample)) return json(502, { error: "FLUX returned an unexpected image URL. Studio credits were not used." });

    const imageRes = await deps.fetch(sample);
    if (!imageRes.ok) return json(502, { error: "Couldn't download the FLUX image. Studio credits were not used." });
    const outBytes = new Uint8Array(await imageRes.arrayBuffer());

    const id = (deps.uuid || (() => crypto.randomUUID()))();
    const path = `${session.userId}/generations/${id}.jpg`;
    await deps.upload(path, outBytes, "image/jpeg");

    const requestedOutfit = body.meta?.outfit_id ? String(body.meta.outfit_id) : "";
    const outfitId = requestedOutfit ? await deps.outfitOwned(session.userId, requestedOutfit) : null;
    const row = {
      id,
      user_id: session.userId,
      path,
      kind: rows.length > 1 || outfitId ? "outfit_flux" : "tryon",
      preset: "flux_vto",
      credits: FLUX_STUDIO_CREDITS,
      garment_id: rows[0].id,
      outfit_id: outfitId,
      prompt,
      style: {
        engine: "flux-vto-v2",
        fidelity: "exact",
        garment_ids: rows.map((row) => row.id),
        garment_names: rows.map((row) => cleanText(row.name)),
      },
    };

    try {
      await deps.insertGeneration(row);
    } catch (e) {
      await Promise.resolve(deps.remove(path)).catch(() => {});
      return failure(500, `The photo was generated but couldn't be saved (${e.message}). Studio credits were not used.`, key);
    }

    return json(200, {
      id,
      generation_id: id,
      path,
      credits: FLUX_STUDIO_CREDITS,
      used_today: me.used_today + FLUX_STUDIO_CREDITS,
      daily_cap: me.daily_cap,
      preset: "flux_vto",
    });
  } catch (e) {
    return failure(500, `${e?.message || "FLUX try-on failed."} Studio credits were not used.`, key);
  }
}
