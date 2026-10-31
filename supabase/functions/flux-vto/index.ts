// FLUX VTO v2 for ClosetIQ Studio. The browser never sees BFL_API_KEY.
//
// Deploy (from the repo root, with the Supabase CLI logged in):
//   supabase link --project-ref yjjdzugecimjwgwtkwyw
//   supabase secrets set BFL_API_KEY=your-key-here
//   supabase functions deploy flux-vto --project-ref yjjdzugecimjwgwtkwyw
//
// SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY are injected
// into the function by Supabase. Do not put them in the repo.
// No SQL migration is required. See supabase/flux_vto_checks.sql to confirm
// the generations columns after the first real try-on.

import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import { Image } from "https://deno.land/x/imagescript@1.3.0/mod.ts";
import { handleFlux, insertGenerationFallback, safeStoragePath } from "../_shared/flux_handler.mjs";

const BUCKET = "studio";

function env(name: string) {
  return Deno.env.get(name) ?? "";
}

function adminClient() {
  const url = env("SUPABASE_URL");
  const service = env("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !service) throw new Error("SUPABASE_SERVICE_ROLE_KEY is not available to this function.");
  return createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });
}

Deno.serve((req) => handleFlux(req, {
  Image,
  getEnv: env,
  fetch: globalThis.fetch.bind(globalThis),
  async loadSession(auth: string) {
    const url = env("SUPABASE_URL");
    const anon = env("SUPABASE_ANON_KEY");
    if (!url || !anon) throw new Error("SUPABASE_URL or SUPABASE_ANON_KEY is missing.");
    const userClient = createClient(url, anon, {
      global: { headers: { Authorization: auth } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data, error } = await userClient.auth.getUser();
    if (error || !data?.user) return null;
    return { userId: data.user.id };
  },
  async studioMe(auth: string) {
    const response = await fetch(`${env("SUPABASE_URL")}/functions/v1/studio/api/me`, {
      headers: { Authorization: auth, apikey: env("SUPABASE_ANON_KEY") },
    });
    if (!response.ok) return null;
    const body = await response.json().catch(() => null);
    if (!body || typeof body.used_today !== "number" || typeof body.daily_cap !== "number") return null;
    return { used_today: body.used_today, daily_cap: body.daily_cap, tz: body.tz || "UTC" };
  },
  async garments(userId: string, ids: string[]) {
    const admin = adminClient();
    const { data, error } = await admin.from("garments")
      .select("id,user_id,path,cutout_path,name,notes,source")
      .in("id", ids)
      .eq("user_id", userId);
    if (error) throw new Error(error.message);
    return data || [];
  },
  async personOwned(userId: string, path: string) {
    const stored = safeStoragePath(path);
    const admin = adminClient();
    const [selfies, models, generations] = await Promise.all([
      admin.from("selfies").select("id").eq("user_id", userId).eq("path", stored).limit(1),
      admin.from("models").select("id,user_id,kind").eq("path", stored).limit(5),
      admin.from("generations").select("id").eq("user_id", userId).eq("path", stored).limit(1),
    ]);
    if (selfies.error) throw new Error(selfies.error.message);
    if (models.error) throw new Error(models.error.message);
    if (generations.error) throw new Error(generations.error.message);
    if (selfies.data?.length || generations.data?.length) return true;
    return (models.data || []).some((model) => model.user_id === userId || model.kind === "default");
  },
  async outfitOwned(userId: string, outfitId: string) {
    const admin = adminClient();
    const { data, error } = await admin.from("outfits").select("id").eq("id", outfitId).eq("user_id", userId).maybeSingle();
    if (error) return null;
    return data?.id || null;
  },
  async download(path: string) {
    const admin = adminClient();
    const { data, error } = await admin.storage.from(BUCKET).download(safeStoragePath(path));
    if (error || !data) throw new Error(error?.message || "Couldn't read a photo.");
    return new Uint8Array(await data.arrayBuffer());
  },
  async upload(path: string, bytes: Uint8Array, contentType: string) {
    const admin = adminClient();
    const { error } = await admin.storage.from(BUCKET).upload(safeStoragePath(path), bytes, { contentType, upsert: true });
    if (error) throw new Error(error.message);
  },
  async remove(path: string) {
    const admin = adminClient();
    await admin.storage.from(BUCKET).remove([safeStoragePath(path)]);
  },
  async insertGeneration(row: Record<string, unknown>) {
    const admin = adminClient();
    return insertGenerationFallback(async (variant) => {
      const { data, error } = await admin.from("generations").insert(variant).select("id,path").single();
      if (error) return { ok: false, error: error.message };
      return { ok: true, data };
    }, row);
  },
}));
