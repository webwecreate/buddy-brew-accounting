-- Bean switch log (2026-11-28): which coffee bean is really in the grinder for each roast level and when,
-- so sales of generic POS options (e.g. "Special Beans", "House Blend") can be credited to the actual bean.
-- Names avoid the CRM table public.bean_options (buddy-platform). Data is loaded separately.
-- Apply: supabase db query --linked -f <abs path>
begin;

-- POS bean option (as imported into pos_bill_items.bean / v_option_sales.name) -> roast level
create table if not exists public.bean_pos_option_map (
  pos_option  text primary key,
  roast_level text check (roast_level in ('light', 'medium', 'dark')),   -- null = not known yet
  note        text,
  updated_at  timestamptz not null default now()
);

-- one row per switch: from start_date the bean below is used
--   pos_option null -> the main bean of that roast level (sold under the generic options of that level)
--   pos_option set  -> a bean sold under its own POS option (e.g. "Mae Bu Yah")
-- a row lasts until the next row of the same slot (same roast_level + pos_option), or until end_date if set
create table if not exists public.bean_usage_periods (
  id          bigint generated always as identity primary key,
  roast_level text not null check (roast_level in ('light', 'medium', 'dark')),
  pos_option  text,
  start_date  date not null,
  end_date    date check (end_date is null or end_date >= start_date),
  bean_name   text not null,
  roaster     text,
  process     text,
  cost_per_g  numeric(10,4),
  source      text,
  note        text,
  created_at  timestamptz not null default now()
);
create unique index if not exists bean_usage_periods_slot_start_uq
  on public.bean_usage_periods (roast_level, coalesce(pos_option, ''), start_date);

do $$
declare t text;
begin
  foreach t in array array['bean_pos_option_map','bean_usage_periods'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy %I on public.%I for select to authenticated using (public.has_app_role(array[''owner'',''manager'']))', t || '_select', t);
    execute format('create policy %I on public.%I for all to authenticated using (public.has_app_role(array[''owner''])) with check (public.has_app_role(array[''owner'']))', t || '_write', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('revoke all on public.%I from anon', t);
  end loop;
end $$;

notify pgrst, 'reload schema';
commit;
