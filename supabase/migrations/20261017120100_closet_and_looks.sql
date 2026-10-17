-- Closet items, outfits, and the shared look model.
-- outfit_items is the only list of products in a look. Storefront-only
-- details (hotspot, order, hidden) live in shop_look_item_meta. Adding a
-- piece in the closet or on the storefront is the same insert, so both
-- sides stay in sync. The public page reads the live rows, not a snapshot.

create table public.garments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  name text not null default '',
  brand text not null default '',
  category text not null default 'other',
  notes text not null default '',
  source text not null default 'manual',
  photo_path text,
  thumb_path text,
  cutout_path text,
  source_path text,
  image_url text,
  price_cents integer,
  price_text text,
  product_url text,
  affiliate_url text,
  asin text,
  public_ok boolean not null default false,
  not_monetized boolean generated always as (
    affiliate_url is null or btrim(affiliate_url) = ''
  ) stored,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint garments_source check (source in ('manual', 'amazon', 'import')),
  constraint garments_category check (
    category in ('tops', 'bottoms', 'one-pieces', 'dresses', 'shoes', 'bag', 'handbags', 'accessory', 'accessories', 'other')
  ),
  constraint garments_name_len check (char_length(name) <= 200),
  constraint garments_price check (price_cents is null or (price_cents >= 0 and price_cents <= 100000000)),
  constraint garments_product_https check (product_url is null or product_url ~ '^https://'),
  constraint garments_affiliate_https check (affiliate_url is null or affiliate_url ~ '^https://'),
  constraint garments_image_https check (image_url is null or image_url ~ '^https://'),
  constraint garments_asin check (asin is null or asin ~ '^[A-Z0-9]{10}$')
);

create index garments_user_idx on public.garments (user_id, created_at desc);

create table public.outfits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  name text not null default 'Untitled look',
  caption text not null default '',
  idea text not null default '',
  hero_generation_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint outfits_name_len check (char_length(name) between 1 and 120)
);

create index outfits_user_idx on public.outfits (user_id, updated_at desc);

create table public.outfit_items (
  outfit_id uuid not null references public.outfits (id) on delete cascade,
  garment_id uuid not null references public.garments (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  position integer not null default 0,
  created_at timestamptz not null default now(),
  primary key (outfit_id, garment_id)
);

create index outfit_items_user_idx on public.outfit_items (user_id);

create table public.shop_pages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  outfit_id uuid not null unique references public.outfits (id) on delete cascade,
  slug text not null unique,
  title text not null,
  caption text,
  disclosure text,
  published boolean not null default false,
  published_at timestamptz,
  listed boolean not null default true,
  featured boolean not null default false,
  sort_order integer not null default 0,
  category text,
  collage_id uuid,
  collage_public_path text,
  cover_public_path text,
  cover_source text not null default 'photo',
  image_needs_rerender boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shop_pages_slug check (slug ~ '^[a-z0-9]{6,16}$'),
  constraint shop_pages_cover_source check (cover_source in ('photo', 'collage', 'custom'))
);

create index shop_pages_user_idx on public.shop_pages (user_id, published, listed);

create table public.shop_look_item_meta (
  outfit_id uuid not null references public.outfits (id) on delete cascade,
  garment_id uuid not null references public.garments (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  hotspot jsonb,
  hidden boolean not null default false,
  position integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (outfit_id, garment_id),
  constraint shop_meta_hotspot check (
    hotspot is null or (
      jsonb_typeof(hotspot) = 'object'
      and (hotspot ->> 'x') ~ '^[0-9.]+$'
      and (hotspot ->> 'y') ~ '^[0-9.]+$'
    )
  )
);

-- Live product list for a look. security_invoker so closet RLS still applies
-- when a creator reads it. Shoppers do not query this view; they use
-- storefront_by_handle.
create view public.look_items
with (security_invoker = true) as
select
  oi.outfit_id,
  oi.garment_id,
  oi.user_id,
  g.name,
  g.brand,
  g.price_text,
  g.price_cents,
  g.affiliate_url,
  g.product_url,
  g.image_url,
  g.asin,
  g.source,
  g.not_monetized,
  coalesce(m.position, oi.position) as position,
  coalesce(m.hidden, false) as hidden,
  m.hotspot
from public.outfit_items oi
join public.garments g on g.id = oi.garment_id
left join public.shop_look_item_meta m
  on m.outfit_id = oi.outfit_id and m.garment_id = oi.garment_id;

create table public.shop_products (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  garment_id uuid not null unique references public.garments (id) on delete cascade,
  name text not null,
  brand text,
  category text not null default 'accessories',
  image_public_path text,
  published boolean not null default false,
  featured boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.shop_collections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  name text not null,
  hidden boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shop_collections_name check (char_length(btrim(name)) between 1 and 80)
);

create table public.shop_collection_looks (
  collection_id uuid not null references public.shop_collections (id) on delete cascade,
  outfit_id uuid not null references public.outfits (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  position integer not null default 0,
  primary key (collection_id, outfit_id)
);

-- Reminders only. No social tokens are stored. Auto-posting is a later phase
-- and, per the platform decision, would be web-only.
create table public.scheduled_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  outfit_id uuid references public.outfits (id) on delete set null,
  title text not null,
  caption text not null default '',
  networks text[] not null default '{}',
  scheduled_for timestamptz not null,
  status text not null default 'reminder',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint scheduled_posts_status check (status in ('reminder', 'draft', 'cancelled')),
  constraint scheduled_posts_title check (char_length(title) between 1 and 120)
);

create index scheduled_posts_user_idx on public.scheduled_posts (user_id, scheduled_for);

-- Tables the current Studio already uses. The new app does not drive them yet.
-- They are here so a later phase can move try-on, collages and reels without
-- another ownership model.
create table public.selfies (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  path text not null,
  thumb_path text,
  label text not null default '',
  ref_role text,
  ref_rank integer,
  created_at timestamptz not null default now()
);

create table public.models (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles (id) on delete cascade,
  path text,
  thumb_path text,
  name text not null default '',
  kind text not null default 'ai_model',
  created_at timestamptz not null default now(),
  constraint models_kind check (kind in ('ai_model', 'ai_self', 'default'))
);

create table public.generations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  outfit_id uuid references public.outfits (id) on delete set null,
  path text,
  cutout_path text,
  prompt text,
  preset text,
  created_at timestamptz not null default now()
);

alter table public.outfits
  add constraint outfits_hero_fk
  foreign key (hero_generation_id) references public.generations (id) on delete set null;

create table public.collages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  outfit_id uuid references public.outfits (id) on delete set null,
  name text not null default '',
  layout jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.reels (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  outfit_id uuid references public.outfits (id) on delete set null,
  collage_id uuid references public.collages (id) on delete set null,
  name text not null default '',
  template text,
  theme text,
  duration_s numeric,
  caption text not null default '',
  links jsonb not null default '[]'::jsonb,
  path text,
  poster_path text,
  mime text,
  size_bytes integer,
  width integer,
  height integer,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Sync triggers
-- ---------------------------------------------------------------------------

create or replace function public.blank_to_null()
returns trigger
language plpgsql
as $$
begin
  if new.affiliate_url is not null and btrim(new.affiliate_url) = '' then
    new.affiliate_url = null;
  end if;
  if new.product_url is not null and btrim(new.product_url) = '' then
    new.product_url = null;
  end if;
  if new.image_url is not null and btrim(new.image_url) = '' then
    new.image_url = null;
  end if;
  if new.asin is not null then
    new.asin = nullif(upper(btrim(new.asin)), '');
  end if;
  return new;
end;
$$;

create trigger garments_blank
  before insert or update on public.garments
  for each row execute function public.blank_to_null();

create or replace function public.short_id()
returns text
language sql
volatile
as $$
  select substr(replace(gen_random_uuid()::text, '-', ''), 1, 10);
$$;

create or replace function public.ensure_shop_page()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_slug text;
  v_try integer := 0;
begin
  if exists (select 1 from public.shop_pages where outfit_id = new.id) then
    return new;
  end if;
  loop
    v_try := v_try + 1;
    v_slug := public.short_id();
    begin
      insert into public.shop_pages (user_id, outfit_id, slug, title, published)
      values (new.user_id, new.id, v_slug, left(new.name, 120), false);
      exit;
    exception when unique_violation then
      if v_try >= 5 then
        raise;
      end if;
    end;
  end loop;
  return new;
end;
$$;

create trigger outfits_shop_page
  after insert on public.outfits
  for each row execute function public.ensure_shop_page();

create or replace function public.prepare_outfit_item()
returns trigger
language plpgsql
as $$
declare
  v_outfit uuid;
  v_garment uuid;
begin
  if auth.uid() is not null then
    new.user_id = auth.uid();
  elsif new.user_id is null then
    raise exception 'Not signed in';
  end if;
  select user_id into v_outfit from public.outfits where id = new.outfit_id;
  select user_id into v_garment from public.garments where id = new.garment_id;
  if v_outfit is null or v_garment is null or v_outfit <> new.user_id or v_garment <> new.user_id then
    raise exception 'That piece is not in your closet';
  end if;
  if tg_op = 'INSERT' and (new.position is null or new.position = 0) then
    select coalesce(max(position), 0) + 1 into new.position
    from public.outfit_items where outfit_id = new.outfit_id;
  end if;
  return new;
end;
$$;

create trigger outfit_items_prepare
  before insert or update on public.outfit_items
  for each row execute function public.prepare_outfit_item();

create or replace function public.sync_look_meta_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.shop_look_item_meta (outfit_id, garment_id, user_id, position, hidden)
  values (new.outfit_id, new.garment_id, new.user_id, new.position, false)
  on conflict (outfit_id, garment_id) do update
    set position = excluded.position
    where shop_look_item_meta.position = 0;
  update public.shop_pages
    set image_needs_rerender = true
    where outfit_id = new.outfit_id;
  return new;
end;
$$;

create trigger outfit_items_sync_meta
  after insert on public.outfit_items
  for each row execute function public.sync_look_meta_insert();

create or replace function public.sync_look_meta_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.shop_look_item_meta
  where outfit_id = old.outfit_id and garment_id = old.garment_id;
  update public.shop_pages
    set image_needs_rerender = true
    where outfit_id = old.outfit_id;
  return old;
end;
$$;

create trigger outfit_items_drop_meta
  after delete on public.outfit_items
  for each row execute function public.sync_look_meta_delete();

create or replace function public.flag_hotspot_rerender()
returns trigger
language plpgsql
as $$
begin
  if new.hotspot is distinct from old.hotspot then
    update public.shop_pages
      set image_needs_rerender = true
      where outfit_id = new.outfit_id;
  end if;
  return new;
end;
$$;

create trigger shop_meta_hotspot
  after update of hotspot on public.shop_look_item_meta
  for each row execute function public.flag_hotspot_rerender();

-- ---------------------------------------------------------------------------
-- Ownership + RLS
-- ---------------------------------------------------------------------------

create or replace function public.guard_owned_outfit()
returns trigger
language plpgsql
as $$
declare
  v_owner uuid;
begin
  if auth.uid() is not null then
    new.user_id = auth.uid();
  elsif new.user_id is null then
    raise exception 'Not signed in';
  end if;
  if new.outfit_id is not null then
    select user_id into v_owner from public.outfits where id = new.outfit_id;
    if v_owner is distinct from new.user_id then
      raise exception 'Look not found';
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.guard_look_meta()
returns trigger
language plpgsql
as $$
declare
  v_owner uuid;
begin
  if auth.uid() is not null then
    new.user_id = auth.uid();
  elsif new.user_id is null then
    raise exception 'Not signed in';
  end if;
  select user_id into v_owner from public.outfits where id = new.outfit_id;
  if v_owner is distinct from new.user_id then
    raise exception 'Look not found';
  end if;
  if (select user_id from public.garments where id = new.garment_id) is distinct from new.user_id then
    raise exception 'Item not found';
  end if;
  return new;
end;
$$;

create or replace function public.guard_shop_product()
returns trigger
language plpgsql
as $$
begin
  if auth.uid() is not null then
    new.user_id = auth.uid();
  elsif new.user_id is null then
    raise exception 'Not signed in';
  end if;
  if (select user_id from public.garments where id = new.garment_id) is distinct from new.user_id then
    raise exception 'Item not found';
  end if;
  return new;
end;
$$;

create trigger garments_user before insert or update on public.garments
  for each row execute function public.force_user_id();
create trigger outfits_user before insert or update on public.outfits
  for each row execute function public.force_user_id();
create trigger shop_pages_user before insert or update on public.shop_pages
  for each row execute function public.guard_owned_outfit();
create trigger shop_meta_user before insert or update on public.shop_look_item_meta
  for each row execute function public.guard_look_meta();
create trigger shop_products_user before insert or update on public.shop_products
  for each row execute function public.guard_shop_product();
create trigger shop_collections_user before insert or update on public.shop_collections
  for each row execute function public.force_user_id();
create or replace function public.guard_collection_look()
returns trigger
language plpgsql
as $$
declare
  v_owner uuid;
begin
  if auth.uid() is not null then
    new.user_id = auth.uid();
  elsif new.user_id is null then
    raise exception 'Not signed in';
  end if;
  select user_id into v_owner from public.shop_collections where id = new.collection_id;
  if v_owner is distinct from new.user_id then
    raise exception 'Collection not found';
  end if;
  select user_id into v_owner from public.outfits where id = new.outfit_id;
  if v_owner is distinct from new.user_id then
    raise exception 'Look not found';
  end if;
  return new;
end;
$$;

create trigger shop_collection_looks_user before insert or update on public.shop_collection_looks
  for each row execute function public.guard_collection_look();
create trigger scheduled_posts_user before insert or update on public.scheduled_posts
  for each row execute function public.guard_owned_outfit();
create trigger selfies_user before insert or update on public.selfies
  for each row execute function public.force_user_id();
create trigger generations_user before insert or update on public.generations
  for each row execute function public.force_user_id();
create trigger collages_user before insert or update on public.collages
  for each row execute function public.force_user_id();
create trigger reels_user before insert or update on public.reels
  for each row execute function public.force_user_id();

create trigger garments_touch before update on public.garments
  for each row execute function public.set_updated_at();
create trigger outfits_touch before update on public.outfits
  for each row execute function public.set_updated_at();
create trigger shop_pages_touch before update on public.shop_pages
  for each row execute function public.set_updated_at();
create trigger shop_products_touch before update on public.shop_products
  for each row execute function public.set_updated_at();
create trigger shop_collections_touch before update on public.shop_collections
  for each row execute function public.set_updated_at();
create trigger scheduled_posts_touch before update on public.scheduled_posts
  for each row execute function public.set_updated_at();
create trigger collages_touch before update on public.collages
  for each row execute function public.set_updated_at();

alter table public.garments enable row level security;
alter table public.outfits enable row level security;
alter table public.outfit_items enable row level security;
alter table public.shop_pages enable row level security;
alter table public.shop_look_item_meta enable row level security;
alter table public.shop_products enable row level security;
alter table public.shop_collections enable row level security;
alter table public.shop_collection_looks enable row level security;
alter table public.scheduled_posts enable row level security;
alter table public.selfies enable row level security;
alter table public.models enable row level security;
alter table public.generations enable row level security;
alter table public.collages enable row level security;
alter table public.reels enable row level security;

grant select, insert, update, delete on public.garments to authenticated;
grant select, insert, update, delete on public.outfits to authenticated;
grant select, insert, update, delete on public.outfit_items to authenticated;
grant select, insert, update, delete on public.shop_pages to authenticated;
grant select, insert, update, delete on public.shop_look_item_meta to authenticated;
grant select, insert, update, delete on public.shop_products to authenticated;
grant select, insert, update, delete on public.shop_collections to authenticated;
grant select, insert, update, delete on public.shop_collection_looks to authenticated;
grant select, insert, update, delete on public.scheduled_posts to authenticated;
grant select, insert, update, delete on public.selfies to authenticated;
grant select, insert, update, delete on public.models to authenticated;
grant select, insert, update, delete on public.generations to authenticated;
grant select, insert, update, delete on public.collages to authenticated;
grant select, insert, update, delete on public.reels to authenticated;
grant select on public.look_items to authenticated;

revoke all on public.garments from anon;
revoke all on public.outfits from anon;
revoke all on public.outfit_items from anon;
revoke all on public.shop_pages from anon;
revoke all on public.shop_look_item_meta from anon;
revoke all on public.shop_products from anon;
revoke all on public.shop_collections from anon;
revoke all on public.shop_collection_looks from anon;
revoke all on public.scheduled_posts from anon;
revoke all on public.selfies from anon;
revoke all on public.models from anon;
revoke all on public.generations from anon;
revoke all on public.collages from anon;
revoke all on public.reels from anon;
revoke all on public.look_items from anon;

create policy garments_own on public.garments for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy outfits_own on public.outfits for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy outfit_items_own on public.outfit_items for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy shop_pages_own on public.shop_pages for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy shop_meta_own on public.shop_look_item_meta for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy shop_products_own on public.shop_products for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy shop_collections_own on public.shop_collections for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy shop_collection_looks_own on public.shop_collection_looks for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy scheduled_posts_own on public.scheduled_posts for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy selfies_own on public.selfies for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy models_read on public.models for select to authenticated
  using (user_id = auth.uid() or user_id is null);
create policy models_write on public.models for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy generations_own on public.generations for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy collages_own on public.collages for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy reels_own on public.reels for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
