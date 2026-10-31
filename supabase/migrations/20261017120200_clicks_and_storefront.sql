-- Click logs and the public storefront read.
-- /go/<id> calls log_click, which records the click and returns the original
-- affiliate URL. The destination is not rewritten.

create table public.tracked_links (
  id text primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  garment_id uuid references public.garments (id) on delete cascade,
  outfit_id uuid references public.outfits (id) on delete set null,
  post_id uuid references public.scheduled_posts (id) on delete cascade,
  destination_url text not null,
  source text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint tracked_links_source check (source in ('storefront', 'post')),
  constraint tracked_links_https check (destination_url ~ '^https://'),
  constraint tracked_links_id check (id ~ '^[a-z0-9]{6,16}$'),
  constraint tracked_links_target check (garment_id is not null or outfit_id is not null)
);

create unique index tracked_links_storefront_garment
  on public.tracked_links (garment_id)
  where source = 'storefront' and garment_id is not null;

create unique index tracked_links_post_garment
  on public.tracked_links (post_id, garment_id)
  where source = 'post' and post_id is not null and garment_id is not null;

create index tracked_links_user_idx on public.tracked_links (user_id);

create table public.link_clicks (
  id bigint generated always as identity primary key,
  link_id text not null references public.tracked_links (id) on delete cascade,
  clicked_at timestamptz not null default now(),
  referrer text
);

create index link_clicks_link_idx on public.link_clicks (link_id, clicked_at desc);

alter table public.tracked_links enable row level security;
alter table public.link_clicks enable row level security;

grant select on public.tracked_links to authenticated;
grant select on public.link_clicks to authenticated;
revoke all on public.tracked_links from anon;
revoke all on public.link_clicks from anon;

create policy tracked_links_select_own on public.tracked_links
  for select to authenticated using (user_id = auth.uid());

create policy link_clicks_select_own on public.link_clicks
  for select to authenticated using (
    exists (
      select 1 from public.tracked_links t
      where t.id = link_id and t.user_id = auth.uid()
    )
  );

-- One storefront redirect per clothing item. Created when an affiliate link
-- is saved, paused when the link is removed. Creators cannot insert rows.
create or replace function public.ensure_storefront_link()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_existing text;
begin
  if new.affiliate_url is null or new.affiliate_url !~ '^https://' then
    update public.tracked_links
      set active = false, updated_at = now()
      where garment_id = new.id and source = 'storefront';
    return new;
  end if;
  select id into v_existing
  from public.tracked_links
  where garment_id = new.id and source = 'storefront';
  if v_existing is null then
    insert into public.tracked_links (id, user_id, garment_id, destination_url, source, active)
    values (public.short_id(), new.user_id, new.id, new.affiliate_url, 'storefront', true);
  else
    update public.tracked_links
      set destination_url = new.affiliate_url, active = true, updated_at = now()
      where id = v_existing;
  end if;
  return new;
end;
$$;

create trigger garments_tracked_link
  after insert or update of affiliate_url, user_id on public.garments
  for each row execute function public.ensure_storefront_link();

-- Post captions use their own redirects so storefront clicks and post clicks
-- stay separate. The destination is still the creator's affiliate URL.
create or replace function public.refresh_post_links(p_post uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post public.scheduled_posts%rowtype;
  v_item record;
  v_count integer := 0;
  v_existing text;
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;
  select * into v_post from public.scheduled_posts
  where id = p_post and user_id = auth.uid();
  if v_post.id is null then
    raise exception 'Post not found';
  end if;
  if v_post.outfit_id is null then
    return 0;
  end if;
  for v_item in
    select g.id as garment_id, g.affiliate_url
    from public.outfit_items oi
    join public.garments g on g.id = oi.garment_id
    where oi.outfit_id = v_post.outfit_id
      and g.affiliate_url ~ '^https://'
  loop
    select id into v_existing
    from public.tracked_links
    where post_id = v_post.id and garment_id = v_item.garment_id and source = 'post';
    if v_existing is null then
      insert into public.tracked_links (id, user_id, garment_id, outfit_id, post_id, destination_url, source, active)
      values (public.short_id(), v_post.user_id, v_item.garment_id, v_post.outfit_id, v_post.id, v_item.affiliate_url, 'post', true);
    else
      update public.tracked_links
        set destination_url = v_item.affiliate_url, active = true, updated_at = now()
        where id = v_existing;
    end if;
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

create or replace function public.log_click(p_id text, p_referrer text default null)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url text;
begin
  if p_id is null or p_id !~ '^[a-z0-9]{6,16}$' then
    return null;
  end if;
  select destination_url into v_url
  from public.tracked_links
  where id = p_id and active and destination_url ~ '^https://';
  if v_url is null then
    return null;
  end if;
  insert into public.link_clicks (link_id, referrer)
  values (p_id, nullif(left(coalesce(p_referrer, ''), 500), ''));
  return v_url;
end;
$$;

create or replace function public.my_click_summary()
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select jsonb_build_object(
    'clicks_7d', (
      select count(*)
      from public.link_clicks c
      join public.tracked_links t on t.id = c.link_id
      where t.user_id = auth.uid()
        and c.clicked_at > now() - interval '7 days'
    ),
    'clicks_prev_7d', (
      select count(*)
      from public.link_clicks c
      join public.tracked_links t on t.id = c.link_id
      where t.user_id = auth.uid()
        and c.clicked_at <= now() - interval '7 days'
        and c.clicked_at > now() - interval '14 days'
    )
  );
$$;

create or replace function public.storefront_by_handle(p_handle text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_handle text := lower(regexp_replace(coalesce(p_handle, ''), '^@', ''));
  v_user uuid;
  v_result jsonb;
begin
  if not public.handle_is_valid(v_handle) then
    return null;
  end if;
  select user_id into v_user from public.creator_settings where handle = v_handle;
  if v_user is null then
    return null;
  end if;

  select jsonb_build_object(
    'handle', s.handle,
    'title', coalesce(nullif(s.storefront_title, ''), 'Shop My Style'),
    'subtitle', s.storefront_subtitle,
    'disclosure', s.disclosure,
    'about_title', coalesce(nullif(s.about_title, ''), 'Meet ClosetIQ'),
    'about_text', s.about_text,
    'app_store_url', s.app_store_url,
    'amazon_storefront_url', s.amazon_storefront_url,
    'seo_title', s.seo_title,
    'seo_description', s.seo_description,
    'looks', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'slug', p.slug,
          'title', p.title,
          'caption', p.caption,
          'category', p.category,
          'featured', p.featured,
          'cover_path', case when p.cover_public_path ~ '^[A-Za-z0-9/_.-]+$' and p.cover_public_path !~ '\.\.' then p.cover_public_path else null end,
          'collage_path', case when p.collage_public_path ~ '^[A-Za-z0-9/_.-]+$' and p.collage_public_path !~ '\.\.' then p.collage_public_path else null end,
          'updated_at', p.updated_at,
          'items', coalesce((
            select jsonb_agg(
              jsonb_build_object(
                'name', g.name,
                'brand', nullif(g.brand, ''),
                'price_text', g.price_text,
                'image_url', g.image_url,
                'go_id', t.id,
                'not_monetized', g.not_monetized,
                'position', coalesce(m.position, oi.position)
              )
              order by coalesce(m.position, oi.position), g.name
            )
            from public.outfit_items oi
            join public.garments g on g.id = oi.garment_id
            left join public.shop_look_item_meta m
              on m.outfit_id = oi.outfit_id and m.garment_id = oi.garment_id
            left join public.tracked_links t
              on t.garment_id = g.id and t.source = 'storefront' and t.active
            where oi.outfit_id = p.outfit_id
              and coalesce(m.hidden, false) = false
          ), '[]'::jsonb)
        )
        order by p.sort_order, p.updated_at desc
      )
      from public.shop_pages p
      where p.user_id = v_user and p.published and p.listed
    ), '[]'::jsonb),
    'collections', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'name', c.name,
          'looks', coalesce((
            select jsonb_agg(p.slug order by cl.position)
            from public.shop_collection_looks cl
            join public.shop_pages p
              on p.outfit_id = cl.outfit_id
             and p.user_id = v_user
             and p.published
             and p.listed
            where cl.collection_id = c.id
              and cl.user_id = v_user
          ), '[]'::jsonb)
        )
        order by c.sort_order, c.name
      )
      from public.shop_collections c
      where c.user_id = v_user and not c.hidden
    ), '[]'::jsonb),
    'finds', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'name', sp.name,
          'brand', sp.brand,
          'category', sp.category,
          'image_path', case when sp.image_public_path ~ '^[A-Za-z0-9/_.-]+$' and sp.image_public_path !~ '\.\.' then sp.image_public_path else null end,
          'go_id', t.id,
          'featured', sp.featured
        )
        order by sp.featured desc, sp.sort_order, sp.name
      )
      from public.shop_products sp
      join public.garments g on g.id = sp.garment_id
      left join public.tracked_links t
        on t.garment_id = g.id and t.source = 'storefront' and t.active
      where sp.user_id = v_user
        and sp.published
        and t.id is not null
    ), '[]'::jsonb)
  )
  into v_result
  from public.creator_settings s
  where s.user_id = v_user;

  return v_result;
end;
$$;

revoke all on function public.ensure_storefront_link() from public, anon, authenticated;
revoke all on function public.refresh_post_links(uuid) from public;
revoke all on function public.log_click(text, text) from public;
revoke all on function public.my_click_summary() from public;
revoke all on function public.storefront_by_handle(text) from public;

grant execute on function public.refresh_post_links(uuid) to authenticated;
grant execute on function public.log_click(text, text) to anon, authenticated;
grant execute on function public.my_click_summary() to authenticated;
grant execute on function public.storefront_by_handle(text) to anon, authenticated;
