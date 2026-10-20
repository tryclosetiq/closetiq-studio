# ClosetIQ Studio database (files only)

SQL and edge functions for a **new** Supabase project. Do not apply these files to the existing production Studio project, and do not run `supabase link` or `supabase db push` against it.

`config.toml` uses the placeholder id `closetiq-studio-staging`.

## Apply, on the new project only

In filename order:

1. `migrations/20261017120000_profiles_settings_credits.sql` — profile, creator settings (handle, Amazon tag, disclosure), credit balance and ledger. Users can read their balance and cannot change it.
2. `migrations/20261017120100_closet_and_looks.sql` — garments, outfits, outfit items, storefront pages, look meta, collections, reminders.
3. `migrations/20261017120200_clicks_and_storefront.sql` — tracked links, click log, public `storefront_by_handle`.
4. `migrations/20261017120300_storage_and_deletion.sql` — `studio` (private) and `shop` (public) buckets, folder policies, `delete_own_account`.

Shoppers do not get table access. A public storefront is the `storefront_by_handle` function. It returns published looks and omits email, the Amazon tag, and the user id.

## Look sync

`outfit_items` is the only product list for a look. Hotspot, order, and hidden live in `shop_look_item_meta`. Adding a piece from the closet or the storefront editor inserts an `outfit_items` row. Hiding a piece does not delete it. Each outfit gets one `shop_pages` row from a trigger.

A garment with an https affiliate link is monetized. A blank link sets `not_monetized`. Non-Amazon products store a creator photo, name, optional price, and optional affiliate link.

## Edge functions

- `functions/import-product` — signed-in POST. Fetches a public https page and returns name, image, and price. Blocks private hosts. The app falls back to the manual form.
- `functions/go` — public GET. Calls `log_click` and responds 302 to the original https URL. Deploy with JWT verification **off**.

```bash
supabase functions deploy import-product
supabase functions deploy go --no-verify-jwt
```

## Checks

```bash
node --test functions/_shared/product_meta.test.js tests/contract.test.js
```

The contract test reads the SQL. It does not connect to a database. It also fails if a migration names the production project ref or a service-role key.
