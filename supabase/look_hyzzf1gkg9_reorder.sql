-- Sundays Are for the Birds (shop slug hyzzf1gkg9, outfit ec1d6199-c2d7-4543-a7bc-19aa84df83a2).
-- Removes the white ribbed long sleeve tee (ASIN B0BZH47H47) from the look and from that outfit.
-- Puts the two new sweatshirts first: Birds crewneck, then the half-snap pullover.
-- Every other look item stays, in its current order. The clothing row is not deleted.

begin;

delete from public.outfit_items oi
using public.garments g
where oi.outfit_id = 'ec1d6199-c2d7-4543-a7bc-19aa84df83a2'
  and oi.garment_id = g.id
  and (
    upper(coalesce(g.asin, '')) = 'B0BZH47H47'
    or coalesce(g.affiliate_url, '') ilike '%B0BZH47H47%'
    or coalesce(g.product_url, '') ilike '%B0BZH47H47%'
    or coalesce(g.name, '') ilike '%white ribbed long sleeve tee%'
  );

with tee as (
  select id::text as id
  from public.garments g
  where upper(coalesce(g.asin, '')) = 'B0BZH47H47'
     or coalesce(g.affiliate_url, '') ilike '%B0BZH47H47%'
     or coalesce(g.product_url, '') ilike '%B0BZH47H47%'
     or coalesce(g.name, '') ilike '%white ribbed long sleeve tee%'
),
elem as (
  select t.item, t.ord
  from public.shop_pages sp
  cross join lateral jsonb_array_elements(coalesce(sp.items::jsonb, '[]'::jsonb)) with ordinality as t(item, ord)
  where sp.id = '1e4bd739-8759-4e6f-8643-7bb4b178ac26'
),
kept as (
  select item, ord
  from elem
  where not (
    coalesce(item->>'url', '') ilike '%B0BZH47H47%'
    or coalesce(item->>'name', '') ilike '%white ribbed long sleeve tee%'
    or coalesce(item->>'full_name', '') ilike '%white ribbed long sleeve tee%'
    or coalesce(item->>'garment_id', '') in (select id from tee)
  )
),
ranked as (
  select item,
    case item->>'garment_id'
      when 'b9323fe3-ae72-4919-a05e-f80eeef66c44' then 0
      when '0b0daa8a-e981-4923-8f7a-54deb0ed228d' then 1
      else 2
    end as grp,
    ord
  from kept
),
rebuilt as (
  select coalesce(jsonb_agg(item order by grp, ord), '[]'::jsonb) as items
  from ranked
)
update public.shop_pages sp
set items = rebuilt.items,
    updated_at = now()
from rebuilt
where sp.id = '1e4bd739-8759-4e6f-8643-7bb4b178ac26';

with ranked as (
  select oi.garment_id,
         row_number() over (
           order by case oi.garment_id
             when 'b9323fe3-ae72-4919-a05e-f80eeef66c44' then 0
             when '0b0daa8a-e981-4923-8f7a-54deb0ed228d' then 1
             else 2
           end,
           oi.position
         ) - 1 as newpos
  from public.outfit_items oi
  where oi.outfit_id = 'ec1d6199-c2d7-4543-a7bc-19aa84df83a2'
)
update public.outfit_items oi
set position = ranked.newpos
from ranked
where oi.outfit_id = 'ec1d6199-c2d7-4543-a7bc-19aa84df83a2'
  and oi.garment_id = ranked.garment_id
  and oi.position is distinct from ranked.newpos;

commit;

-- Check: Birds crewneck, then the half-snap pullover, then the EFAN crewneck. No white ribbed tee.
select ordinality - 1 as pos, item->>'name' as name, item->>'garment_id' as garment_id, item->>'url' as url
from public.shop_pages sp
cross join lateral jsonb_array_elements(coalesce(sp.items::jsonb, '[]'::jsonb)) with ordinality as t(item, ordinality)
where sp.slug = 'hyzzf1gkg9'
order by ordinality;
