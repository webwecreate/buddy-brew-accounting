-- Finance v2 (2026-11-28): fields and tables for accrual P&L, depreciation from the in-service date,
-- owner equity (capital / drawings), waste from POS promotions and month-end stock from the POS.
-- Data is loaded separately (not in this public repo). Apply: supabase db query --linked -f <abs path>
begin;

-- depreciation starts when the asset is ready to use (shop opening), not on the purchase date
alter table public.assets add column if not exists in_service_date date;
comment on column public.assets.in_service_date is 'Depreciation starts from this month; null = purchase_date.';

-- accrual: the month the cost belongs to (e.g. a utility bill paid in Nov for October usage)
alter table public.expenses add column if not exists accrual_month date check (accrual_month is null or extract(day from accrual_month) = 1);
comment on column public.expenses.accrual_month is 'First day of the month the cost belongs to; null = month of expense_date. P&L uses this, cash flow uses expense_date.';

-- owner equity movements: capital contributed and drawings (salary/personal withdrawals)
alter table public.owner_account_entries drop constraint if exists owner_account_entries_direction_check;
alter table public.owner_account_entries add constraint owner_account_entries_direction_check
  check (direction in ('owner_owes_shop', 'shop_owes_owner', 'settlement', 'capital', 'drawing'));
alter table public.owner_account_entries add column if not exists asset_id uuid references public.assets(id);
alter table public.owner_account_entries add column if not exists payment_account_id uuid references public.payment_accounts(id);

-- POS promotions per item (Grab, Marketing แจก, Barista's drink, Testing, wasted ...)
create table if not exists public.pos_promotions (
  id            bigint generated always as identity primary key,
  used_at       timestamp not null,
  business_date date not null,
  bill_no       text not null,
  menu_name     text not null,
  promo_name    text not null,
  qty           numeric(10,2) not null default 0,
  discount      numeric(12,2) not null default 0,   -- item + bill discount from the POS report (= value at selling price)
  source_file   text,
  imported_at   timestamptz not null default now(),
  unique (used_at, bill_no, menu_name, promo_name)
);
create index if not exists pos_promotions_business_date_idx on public.pos_promotions (business_date);

-- month-end stock (quantities from the POS stock report, valued with our purchase cost per unit)
create table if not exists public.inventory_counts (
  id         bigint generated always as identity primary key,
  count_date date not null,
  item_name  text not null,
  qty        numeric(14,3) not null,
  unit       text,
  unit_cost  numeric(12,4),
  value      numeric(12,2),
  product_id uuid references public.products(id),
  source     text,
  note       text,
  created_at timestamptz not null default now(),
  unique (count_date, item_name)
);

do $$
declare t text;
begin
  foreach t in array array['pos_promotions','inventory_counts'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy %I on public.%I for select to authenticated using (public.has_app_role(array[''owner'',''manager'']))', t || '_select', t);
    execute format('create policy %I on public.%I for all to authenticated using (public.has_app_role(array[''owner''])) with check (public.has_app_role(array[''owner'']))', t || '_write', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('revoke all on public.%I from anon', t);
  end loop;
end $$;

notify pgrst, 'reload schema';
commit;
