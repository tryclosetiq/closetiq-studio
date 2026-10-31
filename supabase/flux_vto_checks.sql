-- Read-only checks for the FLUX VTO function. Nothing here changes data.
-- Run in the Supabase SQL editor after you deploy flux-vto and finish one try-on.
--
-- The function inserts into public.generations and uploads
-- {user_id}/generations/{id}.jpg in the private "studio" bucket.
-- It does not add a table. Credits are the integer on that row (1 per success).

-- Columns the insert uses. style and prompt are optional: the function retries
-- without them if Postgres says the column is missing.
select column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public' and table_name = 'generations'
order by ordinal_position;

-- Latest FLUX photos. preset is flux_vto, credits is 1, kind is tryon or outfit_flux.
select id, preset, kind, credits, garment_id, outfit_id, path, created_at
from public.generations
where preset = 'flux_vto'
order by created_at desc
limit 20;

-- What /me likely compares against the daily cap, if it sums this table.
-- Compare the result with the "N/cap today" figure in Studio after a FLUX run.
-- If Studio's counter does not rise by 1, the existing studio function is not
-- counting these rows and that function (not in this repo) needs to include them.
select user_id, coalesce(sum(credits), 0) as credits_today
from public.generations
where created_at >= date_trunc('day', now())
group by user_id;
