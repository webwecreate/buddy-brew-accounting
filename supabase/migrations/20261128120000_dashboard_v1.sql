-- Dashboard v1 (2026-11-28) — read-only dashboard (docs/dashboard.html) data layer.
-- DRAFT until the owner confirms. Apply: supabase db query --linked -f <abs path of this file>
--
-- Adds (all new names checked against CRM tables in the shared public schema):
--   app_user_roles + has_app_role()  — roles ready for growth (owner now; manager/staff later)
--   pos_bills, pos_bill_items        — POS (FoodStory/Wongnai POS) bill detail, imported from salebybilldetail_*.tsv
--   grab_orders                      — Grab Merchant transaction report (one row per Long Order ID, net incl. adjustments)
--   monthly_targets                  — monthly targets / plan values used by the dashboard
--   fixed_cost_items, shop_closures  — planned fixed costs per month; extra closed days (besides the weekly closed day)
--   account_balances                 — counted balances per payment account (safe, banks) at a date
--   owner_account_entries            — owner <-> shop items not in liabilities (e.g. owner used shop money)
--   menu_costs                       — snapshot of cost/profit per menu from Unit-cost-proposal-3.xlsx (replaced by recipe costing later)
--   views v_sales_daily, v_sales_hourly, v_menu_sales (security_invoker, so RLS of the base tables applies)
-- Existing tables and their policies are NOT changed.
-- RLS on every new table: read = owner/manager, write = owner. No anon access.

begin;

-- ---------- roles ----------
create table if not exists public.app_user_roles (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  role       text not null check (role in ('owner', 'manager', 'staff')),
  created_at timestamptz not null default now()
);
comment on table public.app_user_roles is 'Accounting/back-office roles. owner = full; manager = read finance; staff = recipes/stock only (future).';

create or replace function public.has_app_role(roles text[])
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.app_user_roles r where r.user_id = auth.uid() and r.role = any(roles));
$$;
revoke all on function public.has_app_role(text[]) from public, anon;
revoke all on public.app_user_roles from anon;
grant execute on function public.has_app_role(text[]) to authenticated;

alter table public.app_user_roles enable row level security;
create policy app_user_roles_select on public.app_user_roles for select to authenticated
  using (user_id = auth.uid() or public.has_app_role(array['owner']));
create policy app_user_roles_write on public.app_user_roles for all to authenticated
  using (public.has_app_role(array['owner'])) with check (public.has_app_role(array['owner']));
grant select, insert, update, delete on public.app_user_roles to authenticated;

insert into public.app_user_roles (user_id, role)
values ('0997227d-1fc4-4f3c-a400-3a1ccb1ce53e', 'owner')
on conflict (user_id) do nothing;

-- ---------- POS bills ----------
create table if not exists public.pos_bills (
  paid_date     date not null,                 -- date printed on the POS row
  bill_no       text not null,
  paid_at       timestamp not null,            -- local Bangkok time (no tz)
  business_date date not null,                 -- cut-off 03:00 (bills before 03:00 belong to the previous day)
  business_hour smallint not null,             -- 0..26 (24..26 = after midnight of business_date)
  pay_type      text,
  gross         numeric(12,2) not null default 0,
  discount      numeric(12,2) not null default 0,  -- item discounts only (bill-level discounts are not in this report)
  net           numeric(12,2) not null default 0,
  cups          integer not null default 0,    -- drinks (categories Iced/Hot coffee, Non-coffee, Matcha, Signature, Special menu)
  snacks        integer not null default 0,
  channel       text not null check (channel in ('store', 'grab', 'void')),
  grab_match    text,                          -- grab-promo | grab-pay-no-promo | grab-inferred (from grab_pos_reconcile.classify)
  is_gov        boolean not null default false,-- paid by government scheme (ไทยช่วยไทย / คนละครึ่ง)
  source_file   text,
  imported_at   timestamptz not null default now(),
  primary key (paid_date, bill_no)
);
create index if not exists pos_bills_business_date_idx on public.pos_bills (business_date);
comment on table public.pos_bills is 'POS bills (FoodStory/Wongnai POS salebybilldetail). store revenue = net of channel store; Grab bills are recorded at net 0 (stock only) — Grab money comes from grab_orders.';

create table if not exists public.pos_bill_items (
  id          bigint generated always as identity primary key,
  paid_date   date not null,
  bill_no     text not null,
  line_no     smallint not null,
  menu_code   text,
  menu_name   text not null,                   -- base menu name without options
  menu_full   text,                            -- full POS text incl. options
  temp        text check (temp in ('hot', 'iced')),
  category    text,
  order_type  text,
  qty         numeric(10,2) not null default 0,
  unit_price  numeric(12,2) not null default 0,
  gross       numeric(12,2) not null default 0,
  discount    numeric(12,2) not null default 0,
  net         numeric(12,2) not null default 0,
  bean        text,                            -- coffee bean option (normalised name), e.g. 'Brazil Santos'
  bean_roast  text,                            -- roast text from the option, e.g. 'Medium to dark'
  matcha      text,                            -- matcha option, e.g. 'Yame', 'Rich'
  foreign key (paid_date, bill_no) references public.pos_bills (paid_date, bill_no) on delete cascade,
  unique (paid_date, bill_no, line_no)
);
create index if not exists pos_bill_items_bill_idx on public.pos_bill_items (paid_date, bill_no);

-- ---------- Grab orders ----------
create table if not exists public.grab_orders (
  long_order_id  text primary key,
  short_order_id text,                         -- GF-xxx (repeats across days — never use as key)
  ordered_at     timestamp not null,           -- local time
  business_date  date not null,
  business_hour  smallint not null,
  app_amount     numeric(12,2) not null default 0,  -- app price paid by customer
  payout         numeric(12,2) not null default 0,  -- Total of the payment row
  adjustment     numeric(12,2) not null default 0,  -- revenue adjustments matched by Long Order ID
  net            numeric(12,2) not null default 0,  -- payout + adjustment = money to the shop
  settlement_id  text,
  transfer_date  text,
  is_cash        boolean not null default false,
  source_file    text,
  imported_at    timestamptz not null default now()
);
create index if not exists grab_orders_business_date_idx on public.grab_orders (business_date);

-- ---------- targets / balances / owner account / menu costs ----------
create table if not exists public.monthly_targets (
  month               date primary key check (extract(day from month) = 1),
  open_days_plan      integer,                 -- null = days in month minus weekly closed day minus shop_closures
  sales_target        numeric(12,2),           -- total net sales target (store + Grab)
  cups_target         integer,
  fixed_cost          numeric(12,2),           -- override; null = sum(fixed_cost_items) + depreciation of the month
  owner_salary_target numeric(12,2),
  note                text,
  updated_at          timestamptz not null default now()
);

create table if not exists public.fixed_cost_items (
  id             bigint generated always as identity primary key,
  name           text not null,
  monthly_amount numeric(12,2) not null default 0,
  category_key   text,                         -- expense_categories.key it is compared with (actual spending)
  valid_from     date not null default '2026-05-01',
  valid_to       date,                         -- null = still valid
  note           text,
  sort_order     integer not null default 0
);
comment on table public.fixed_cost_items is 'Planned monthly fixed costs (excl. depreciation, which is computed from assets).';

create table if not exists public.shop_closures (
  closed_date date primary key,
  reason      text,
  created_at  timestamptz not null default now()
);
comment on table public.shop_closures is 'Extra closed days besides the weekly closed day (Friday since Aug 2026).';

create table if not exists public.account_balances (
  id                 bigint generated always as identity primary key,
  payment_account_id uuid not null references public.payment_accounts(id),
  as_of              date not null,
  balance            numeric(12,2) not null,
  note               text,
  created_at         timestamptz not null default now(),
  unique (payment_account_id, as_of)
);

create table if not exists public.owner_account_entries (
  id          bigint generated always as identity primary key,
  entry_date  date,
  amount      numeric(12,2) not null,
  direction   text not null check (direction in ('owner_owes_shop', 'shop_owes_owner', 'settlement')),
  account     text,
  description text,
  status      text not null default 'active',
  note        text,
  source      text,
  created_at  timestamptz not null default now()
);
comment on table public.owner_account_entries is 'Owner <-> shop items NOT in liabilities. Shop debt to owner stays in liabilities (creditor_type owner).';

create table if not exists public.menu_costs (
  id               bigint generated always as identity primary key,
  menu_name        text not null,
  temp             text check (temp in ('hot', 'iced')),
  price_expected   numeric(10,2),             -- average price the customer pays (incl. bean surcharge average)
  cost_dinein      numeric(10,2),
  profit_dinein    numeric(10,2),
  cost_takeaway    numeric(10,2),
  profit_takeaway  numeric(10,2),
  note             text,
  as_of            date not null,
  source           text,
  unique (menu_name, temp, as_of)
);

-- ---------- RLS ----------
do $$
declare t text;
begin
  foreach t in array array['pos_bills','pos_bill_items','grab_orders','monthly_targets','fixed_cost_items','shop_closures','account_balances','owner_account_entries','menu_costs'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy %I on public.%I for select to authenticated using (public.has_app_role(array[''owner'',''manager'']))', t || '_select', t);
    execute format('create policy %I on public.%I for all to authenticated using (public.has_app_role(array[''owner''])) with check (public.has_app_role(array[''owner'']))', t || '_write', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('revoke all on public.%I from anon', t);
  end loop;
end $$;

-- ---------- views (security_invoker: caller's RLS applies) ----------
create or replace view public.v_sales_daily with (security_invoker = true) as
with p as (
  select business_date,
         sum(net)   filter (where channel = 'store')                 as store_net,
         count(*)   filter (where channel = 'store' and net > 0)     as store_bills,
         sum(cups)  filter (where channel = 'store' and net > 0)     as store_cups,
         sum(snacks) filter (where channel = 'store' and net > 0)    as store_snacks,
         sum(cups)  filter (where channel = 'store' and net <= 0)    as free_cups,
         sum(net)   filter (where channel = 'store' and is_gov)      as gov_net,
         sum(cups)  filter (where channel = 'grab')                  as grab_pos_cups
  from public.pos_bills group by business_date
), g as (
  select business_date, count(*) as grab_orders, sum(app_amount) as grab_app_amount, sum(net) as grab_net
  from public.grab_orders group by business_date
)
select coalesce(p.business_date, g.business_date) as business_date,
       coalesce(store_net, 0) as store_net, coalesce(store_bills, 0) as store_bills,
       coalesce(store_cups, 0) as store_cups, coalesce(store_snacks, 0) as store_snacks,
       coalesce(gov_net, 0) as gov_net, coalesce(free_cups, 0) as free_cups, coalesce(grab_pos_cups, 0) as grab_pos_cups,
       coalesce(grab_orders, 0) as grab_orders, coalesce(grab_app_amount, 0) as grab_app_amount,
       coalesce(grab_net, 0) as grab_net
from p full join g on g.business_date = p.business_date;

create or replace view public.v_sales_hourly with (security_invoker = true) as
with p as (
  select business_date, business_hour, sum(net) as store_net, sum(cups) as store_cups, count(*) as store_bills
  from public.pos_bills where channel = 'store' and net > 0 group by 1, 2
), g as (
  select business_date, business_hour, count(*) as grab_orders, sum(net) as grab_net
  from public.grab_orders group by 1, 2
)
select coalesce(p.business_date, g.business_date) as business_date,
       coalesce(p.business_hour, g.business_hour) as business_hour,
       coalesce(store_net, 0) as store_net, coalesce(store_cups, 0) as store_cups, coalesce(store_bills, 0) as store_bills,
       coalesce(grab_orders, 0) as grab_orders, coalesce(grab_net, 0) as grab_net
from p full join g on g.business_date = p.business_date and g.business_hour = p.business_hour;

create or replace view public.v_menu_sales with (security_invoker = true) as
select b.business_date, b.channel, i.menu_name, i.temp, i.category,
       sum(i.qty) as qty, sum(i.gross) as gross, sum(i.net) as net
from public.pos_bill_items i
join public.pos_bills b on b.paid_date = i.paid_date and b.bill_no = i.bill_no
where b.channel in ('store', 'grab')
group by 1, 2, 3, 4, 5;

create or replace view public.v_option_sales with (security_invoker = true) as
select b.business_date, b.channel, 'bean'::text as kind, i.bean as name, max(i.bean_roast) as detail, sum(i.qty) as qty
from public.pos_bill_items i join public.pos_bills b on b.paid_date = i.paid_date and b.bill_no = i.bill_no
where b.channel in ('store', 'grab') and i.bean is not null group by 1, 2, 4
union all
select b.business_date, b.channel, 'matcha', i.matcha, null, sum(i.qty)
from public.pos_bill_items i join public.pos_bills b on b.paid_date = i.paid_date and b.bill_no = i.bill_no
where b.channel in ('store', 'grab') and i.matcha is not null group by 1, 2, 4;

grant select on public.v_sales_daily, public.v_sales_hourly, public.v_menu_sales, public.v_option_sales to authenticated;
revoke all on public.v_sales_daily, public.v_sales_hourly, public.v_menu_sales, public.v_option_sales from anon;

notify pgrst, 'reload schema';
commit;
