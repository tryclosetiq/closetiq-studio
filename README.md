# ClosetIQ Studio

Private, single-user virtual try-on studio. This repository holds only the static page served by
GitHub Pages. All data (photos, clothing, outfits, generated images) lives in a private Supabase
project behind authentication; AI calls go through a server-side function that holds the API keys.

Nothing personal is stored here: the page contains only the Supabase project URL and its public
anon key, which grant no access on their own.
Phase 2 deployment update

## Public multi-creator app (in progress)

The GitHub Pages site above stays as it is. The new iOS and web app is in [`app/`](app/README.md).
Public shopper pages are in [`storefront/`](storefront/README.md). Database files for a **new**
Supabase project are in [`supabase/`](supabase/README.md). Do not apply those migrations to the
project this Pages site already uses.
