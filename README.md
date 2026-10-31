# ClosetIQ Studio

Private, single-user virtual try-on studio. This repository holds only the static page served by
GitHub Pages. All data (photos, clothing, outfits, generated images) lives in a private Supabase
project behind authentication; AI calls go through a server-side function that holds the API keys.

Nothing personal is stored here: the page contains only the Supabase project URL and its public
anon key, which grant no access on their own.
Phase 2 deployment update

## FLUX multi-item try-on

Try-On can dress up to 4 of Heather's own garments in one Black Forest Labs FLUX VTO v2 call.
The browser merges nothing and never sees the BFL key. `supabase/functions/flux-vto` downloads
the photos, builds a 2-column garment grid (512px cells; a single item uses a 1024px cell),
submits `https://api.bfl.ai/v1/flux-tools/vto-v2`, polls, then saves the JPEG under My Photos
the same way other try-ons are stored (`{user}/generations/{id}.jpg` plus a `generations` row).

Until that function is deployed, the page keeps today's FASHN try-on for one item. Several
selected items show **Try on N items · coming soon**, and the outfit sheet's FLUX chip says
the same. A 404 from `/functions/v1/flux-vto` is what turns that on.

### Credit cost

| Run | Studio credits |
| --- | --- |
| FLUX VTO v2, 1–4 items, one image | **1** |
| FASHN HD (existing presets) | unchanged, from `/me` |

1 studio credit is the whole-credit equivalent of BFL's price (about $0.0475 per image; 1 BFL credit = $0.01) against a FASHN credit at $0.075. It is less than the default HD preset, Try-On Max balanced 1K, which is 2 FASHN credits ($0.15). A four-item sequential HD run is 8 credits. Failed, moderated, or timed-out FLUX calls do not write a row and do not add to today's count.

The new row's `credits` is 1 and `preset` is `flux_vto`. Studio's daily counter should rise by 1 if `/me` sums `generations.credits`. Confirm with `supabase/flux_vto_checks.sql` after the first real run. If the header does not move, the existing `studio` function (not in this repo) is not counting these rows.

### Go live

```bash
supabase link --project-ref yjjdzugecimjwgwtkwyw
supabase secrets set BFL_API_KEY=your-key-here
supabase functions deploy flux-vto --project-ref yjjdzugecimjwgwtkwyw
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are injected by Supabase. No SQL migration is required. `verify_jwt` stays on. Do not deploy with `--no-verify-jwt`.
