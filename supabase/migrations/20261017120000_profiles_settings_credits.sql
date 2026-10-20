-- ClosetIQ Studio multi-creator foundation.
-- Apply to a NEW Supabase project only. Do not run this against the live
-- single-user Studio project.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Client writes are pinned to the signed-in user. Signup triggers run without
-- a user JWT, so an explicit user_id is kept in that case.
create or replace function public.force_user_id()
returns trigger
language plpgsql
as $$
begin
  if auth.uid() is not null then
    new.user_id = auth.uid();
  elsif new.user_id is null then
    raise exception 'Not signed in';
  end if;
  return new;
end;
$$;

create or replace function public.handle_is_valid(p_handle text)
returns boolean
language sql
immutable
as $$
  select lower(coalesce(p_handle, '')) ~ '^[a-z0-9_]{3,30}$'
    and lower(p_handle) not in (
      'admin', 'api', 'app', 'account', 'auth', 'closet', 'closetiq', 'create',
      'go', 'help', 'home', 'insights', 'login', 'pricing', 'schedule',
      'signup', 'storefront', 'support', 'www'
    );
$$;

-- ---------------------------------------------------------------------------
-- Profile, per-creator settings, credits
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '',
  onboarding_completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_name_len check (char_length(display_name) <= 80)
);

create table public.creator_settings (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  handle text,
  amazon_tag text,
  disclosure text not null default 'As an Amazon Associate I earn from qualifying purchases.',
  hashtags text,
  amazon_storefront_url text,
  app_store_url text,
  storefront_title text not null default 'Shop My Style',
  storefront_subtitle text,
  about_title text not null default 'Meet ClosetIQ',
  about_text text,
  seo_title text,
  seo_description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint creator_handle_valid check (handle is null or public.handle_is_valid(handle)),
  constraint creator_amazon_tag check (amazon_tag is null or amazon_tag ~ '^[A-Za-z0-9_-]{2,40}$'),
  constraint creator_amazon_store check (
    amazon_storefront_url is null or amazon_storefront_url ~ '^https://([a-z0-9-]+\.)*amazon\.[a-z.]+/'
  ),
  constraint creator_app_store check (
    app_store_url is null or app_store_url ~ '^https://apps\.apple\.com/'
  ),
  constraint creator_disclosure_len check (char_length(disclosure) between 1 and 400)
);

create unique index creator_settings_handle_key
  on public.creator_settings (handle)
  where handle is not null;

create table public.credit_balances (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  balance integer not null default 0,
  monthly_allowance integer not null default 0,
  updated_at timestamptz not null default now(),
  constraint credit_balance_nonnegative check (balance >= 0 and monthly_allowance >= 0)
);

create table public.credit_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  delta integer not null,
  reason text not null,
  created_at timestamptz not null default now(),
  constraint credit_ledger_reason_len check (char_length(reason) between 1 and 120)
);

create index credit_ledger_user_idx on public.credit_ledger (user_id, created_at desc);

-- Billing is a later phase. Creators can read a balance. They cannot grant
-- themselves credits. Service-side jobs write the ledger.
revoke all on public.credit_balances from public, anon, authenticated;
revoke all on public.credit_ledger from public, anon, authenticated;
grant select on public.credit_balances to authenticated;
grant select on public.credit_ledger to authenticated;

create or replace function public.normalize_creator_settings()
returns trigger
language plpgsql
as $$
begin
  if new.handle is not null then
    new.handle = nullif(lower(btrim(new.handle)), '');
  end if;
  if new.amazon_tag is not null then
    new.amazon_tag = nullif(btrim(new.amazon_tag), '');
  end if;
  if new.disclosure is null or btrim(new.disclosure) = '' then
    new.disclosure = 'As an Amazon Associate I earn from qualifying purchases.';
  end if;
  return new;
end;
$$;

create trigger creator_settings_normalize
  before insert or update on public.creator_settings
  for each row execute function public.normalize_creator_settings();

create trigger creator_settings_user
  before insert or update on public.creator_settings
  for each row execute function public.force_user_id();

create trigger profiles_touch
  before update on public.profiles
  for each row execute function public.set_updated_at();

create trigger creator_settings_touch
  before update on public.creator_settings
  for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    left(coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      split_part(new.email, '@', 1),
      'Creator'
    ), 80)
  );
  insert into public.creator_settings (user_id) values (new.id);
  insert into public.credit_balances (user_id, balance, monthly_allowance)
  values (new.id, 0, 0);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.handle_available(p_handle text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.handle_is_valid(p_handle)
    and auth.uid() is not null
    and not exists (
      select 1 from public.creator_settings
      where handle = lower(p_handle)
        and user_id <> auth.uid()
    );
$$;

alter table public.profiles enable row level security;
alter table public.creator_settings enable row level security;
alter table public.credit_balances enable row level security;
alter table public.credit_ledger enable row level security;

create policy profiles_select_own on public.profiles
  for select to authenticated using (id = auth.uid());
create policy profiles_update_own on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy settings_select_own on public.creator_settings
  for select to authenticated using (user_id = auth.uid());
create policy settings_update_own on public.creator_settings
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy credits_select_own on public.credit_balances
  for select to authenticated using (user_id = auth.uid());
create policy ledger_select_own on public.credit_ledger
  for select to authenticated using (user_id = auth.uid());

revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.handle_available(text) from public;
grant execute on function public.handle_available(text) to authenticated;

-- GoTrue inserts the auth user as supabase_auth_admin, which must be allowed
-- to run the signup trigger. The function is not granted to creators.
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'supabase_auth_admin') then
    grant execute on function public.handle_new_user() to supabase_auth_admin;
  end if;
end $$;
