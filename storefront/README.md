# Public storefront

Plain HTML shopper page for `https://closetiq.app/@handle`. Flutter web is the creator tool in `../app/`. This folder is what shoppers open.

With no `config.js`, the page shows example looks and does not call Supabase. Copy `config.example.js` to `config.js` and set the **new** project's URL and anon key. Do not commit `config.js`.

Rewrites, so `/@handle` and `/go/:id` reach this folder:

- `vercel.json` for Vercel
- `_redirects` for Netlify

`go.html` asks `log_click` for the destination, then redirects. The `go` edge function does the same 302 when it is deployed. Clicks are a count only. The affiliate URL is not rewritten.

There are no profiles, follows, or a community on this page.
