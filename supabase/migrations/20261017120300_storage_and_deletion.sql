-- Private creator files and the public shop bucket.
-- Paths are {user_id}/... so one creator cannot read another's studio files.
-- Account deletion removes those files and the auth user. Profiles and every
-- owned row cascade from auth.users.

insert into storage.buckets (id, name, public)
values
  ('studio', 'studio', false),
  ('shop', 'shop', true)
on conflict (id) do nothing;

create or replace function public.storage_owner(p_name text)
returns boolean
language sql
stable
as $$
  select auth.uid() is not null
    and (storage.foldername(p_name))[1] = auth.uid()::text;
$$;

create policy studio_owner_read on storage.objects
  for select to authenticated
  using (bucket_id = 'studio' and public.storage_owner(name));

create policy studio_owner_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'studio' and public.storage_owner(name));

create policy studio_owner_update on storage.objects
  for update to authenticated
  using (bucket_id = 'studio' and public.storage_owner(name))
  with check (bucket_id = 'studio' and public.storage_owner(name));

create policy studio_owner_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'studio' and public.storage_owner(name));

-- Shop images are world-readable. Only the owning creator can write them.
create policy shop_public_read on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'shop');

create policy shop_owner_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'shop' and public.storage_owner(name));

create policy shop_owner_update on storage.objects
  for update to authenticated
  using (bucket_id = 'shop' and public.storage_owner(name))
  with check (bucket_id = 'shop' and public.storage_owner(name));

create policy shop_owner_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'shop' and public.storage_owner(name));

create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not signed in';
  end if;
  delete from storage.objects
  where bucket_id in ('studio', 'shop')
    and (storage.foldername(name))[1] = v_uid::text;
  delete from auth.users where id = v_uid;
end;
$$;

revoke all on function public.delete_own_account() from public, anon;
grant execute on function public.delete_own_account() to authenticated;
