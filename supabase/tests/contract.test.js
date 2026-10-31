import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const sql = readdirSync(join(root, "migrations"))
  .filter((name) => name.endsWith(".sql"))
  .sort()
  .map((name) => readFileSync(join(root, "migrations", name), "utf8"))
  .join("\n");

test("migrations define the multi-creator foundation and do not name production", () => {
  assert.match(sql, /enable row level security/);
  assert.match(sql, /create table public\.outfit_items/);
  assert.match(sql, /create table public\.shop_look_item_meta/);
  assert.match(sql, /create view public\.look_items/);
  assert.match(sql, /not_monetized boolean generated always as/);
  assert.match(sql, /create or replace function public\.log_click/);
  assert.match(sql, /create or replace function public\.storefront_by_handle/);
  assert.match(sql, /create or replace function public\.delete_own_account/);
  assert.match(sql, /create or replace function public\.ensure_storefront_link/);
  assert.match(sql, /bucket_id = 'studio'/);
  assert.match(sql, /bucket_id = 'shop'/);
  assert.doesNotMatch(sql, /yjjdzugecimjwgwtkwyw/);
  assert.doesNotMatch(sql, /service_role/i);
  assert.doesNotMatch(sql, /eyJ/);
});

test("shoppers cannot read closet tables directly", () => {
  for (const table of ["garments", "outfits", "outfit_items", "shop_pages", "selfies", "tracked_links"]) {
    assert.match(sql, new RegExp(`revoke all on public\\.${table} from anon`));
  }
});

test("a look piece inserted either way is the outfit row, with storefront-only fields beside it", () => {
  assert.match(sql, /outfit_items is the only list of products in a look/i);
  assert.match(sql, /after insert on public\.outfit_items/);
  assert.match(sql, /after delete on public\.outfit_items/);
  assert.match(sql, /image_needs_rerender/);
  assert.match(sql, /coalesce\(m\.hidden, false\) = false/);
});
