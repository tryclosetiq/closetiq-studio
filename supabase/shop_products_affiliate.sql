-- Nullable display fields for Individual Finds. Safe to run more than once.
alter table public.shop_products add column if not exists price text;
alter table public.shop_products add column if not exists promo_note text;

update public.shop_products
set price = '$48.99',
    promo_note = 'Use code GREEN20 for 20% off',
    updated_at = now()
where id = 'c937c2fa-f3be-4538-8314-a591d4aa5aa5';
