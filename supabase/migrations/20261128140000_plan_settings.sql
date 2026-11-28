-- Plan settings (2026-11-28): numbers behind the owner's milestone ladder (บันไดเป้าหมาย) used by docs/dashboard.html.
-- Key/value so the back office can edit them later. Values are seeded separately (not in this public repo).
-- Apply: supabase db query --linked -f <abs path of this file>
begin;

create table if not exists public.plan_settings (
  key        text primary key,
  value      numeric not null,
  label      text not null,
  note       text,
  sort_order integer not null default 0,
  updated_at timestamptz not null default now()
);
comment on table public.plan_settings is 'Owner plan parameters: salary levels, owner-debt repayment, rent model, contribution per cup, over-purchase allowance.';

alter table public.plan_settings enable row level security;
create policy plan_settings_select on public.plan_settings for select to authenticated using (public.has_app_role(array['owner','manager']));
create policy plan_settings_write on public.plan_settings for all to authenticated using (public.has_app_role(array['owner'])) with check (public.has_app_role(array['owner']));
grant select, insert, update, delete on public.plan_settings to authenticated;
revoke all on public.plan_settings from anon;

notify pgrst, 'reload schema';
commit;
