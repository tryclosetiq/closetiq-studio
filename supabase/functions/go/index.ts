// Click redirect. Logs the click, then forwards to the creator's affiliate URL
// unchanged. Deploy with verify_jwt = false. Do not deploy to production.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

Deno.serve(async (req) => {
  if (req.method !== "GET" && req.method !== "HEAD") {
    return new Response("Not found", { status: 404 });
  }
  const url = new URL(req.url);
  const parts = url.pathname.split("/").filter(Boolean);
  const id = (url.searchParams.get("id") || parts[parts.length - 1] || "").trim();
  if (!/^[a-z0-9]{6,16}$/i.test(id) || id === "go") {
    return new Response("Link not found", { status: 404, headers: { "cache-control": "no-store" } });
  }

  const base = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || Deno.env.get("SUPABASE_ANON_KEY");
  if (!base || !key) return new Response("Link tracking is not configured.", { status: 500 });

  const supabase = createClient(base, key, { auth: { persistSession: false } });
  const { data, error } = await supabase.rpc("log_click", {
    p_id: id,
    p_referrer: (req.headers.get("referer") || "").slice(0, 500),
  });
  if (error || typeof data !== "string" || !data.startsWith("https://")) {
    return new Response("Link not found", { status: 404, headers: { "cache-control": "no-store" } });
  }
  return new Response(null, {
    status: 302,
    headers: {
      Location: data,
      "referrer-policy": "no-referrer",
      "cache-control": "no-store",
    },
  });
});
