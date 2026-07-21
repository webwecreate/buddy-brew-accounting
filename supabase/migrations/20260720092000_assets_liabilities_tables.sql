-- ทรัพย์สิน (assets) และหนี้สิน (liabilities) — track ว่าร้านมีอะไร ราคาเท่าไหร่ ค่าเสื่อมไปเท่าไหร่
-- และยังเป็นหนี้ใครอยู่ (vendor/เจ้าของ/ธนาคาร) เพราะเจ้าหนี้เปลี่ยนได้ เช่น ผ่อน vendor หมดแล้ว
-- แต่ถ้าเงินที่โปะมาจากกระเป๋าเจ้าของเอง ร้านจะกลายเป็นหนี้เจ้าของแทน ต้องแยก track เป็นรายเจ้าหนี้

create table assets (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null check (category in ('equipment', 'decor')),
  purchase_price numeric not null,
  purchase_date date not null,
  useful_life_months integer not null default 24,  -- ตามธรรมเนียม ÷24 เดือนใน Accounting/fixed_cost_v1.md
  status text not null default 'active' check (status in ('active', 'disposed')),
  disposed_date date,
  note text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

-- ค่าเสื่อมไม่เก็บเป็นคอลัมน์ในตารางนี้ — เป็นฟังก์ชันล้วนของ purchase_price/purchase_date/useful_life_months
-- ไม่มี child table ให้ aggregate จึงคำนวณฝั่ง client ตอนแสดงผลเสมอ (ต่างจาก liabilities.paid_amount ด้านล่าง)

create table liabilities (
  id uuid primary key default gen_random_uuid(),
  creditor_type text not null check (creditor_type in ('vendor', 'owner', 'bank', 'other')),
  creditor_name text not null,             -- ชื่อ vendor หรือชื่อเจ้าของคนที่ออกเงิน — จุดสำคัญของ feature นี้
  asset_id uuid references assets(id) on delete set null,  -- ผูกกับทรัพย์สิน (ไม่บังคับ)
  original_amount numeric not null,
  paid_amount numeric not null default 0,  -- trigger คำนวณจาก liability_payments เหมือน expenses.amount
  start_date date not null,
  status text not null default 'open' check (status in ('open', 'paid_off')),
  note text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table liability_payments (
  id uuid primary key default gen_random_uuid(),
  liability_id uuid not null references liabilities(id) on delete cascade,
  payment_date date not null,
  amount numeric not null,
  note text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

-- trigger เดียวกับแนวทาง trg_recalc_expense_amount: คำนวณ paid_amount ใหม่ทุกครั้งที่มีการจ่ายเพิ่ม/แก้/ลบ
-- และ auto-flip status เป็น paid_off เมื่อจ่ายครบ (กันลืมกดปิดเอง, ย้อนกลับเป็น open ถ้าแก้ยอดจ่ายลดลงทีหลัง)
create function recalc_liability_paid_amount() returns trigger as $$
declare
  target_liability_id uuid;
  new_paid numeric;
  target_original numeric;
begin
  target_liability_id := coalesce(new.liability_id, old.liability_id);
  select coalesce(sum(amount), 0) into new_paid from liability_payments where liability_id = target_liability_id;
  select original_amount into target_original from liabilities where id = target_liability_id;
  update liabilities
    set paid_amount = new_paid,
        status = case when new_paid >= target_original then 'paid_off' else 'open' end
    where id = target_liability_id;
  return null;
end;
$$ language plpgsql;

create trigger trg_recalc_liability_paid_amount
  after insert or update or delete on liability_payments
  for each row execute function recalc_liability_paid_amount();

-- RLS: เหมือนตารางอื่นทั้งหมดในระบบนี้ (authenticated เข้าได้ทุกอย่าง ไม่มี anon)
alter table assets enable row level security;
alter table liabilities enable row level security;
alter table liability_payments enable row level security;

grant select, insert, update, delete on table assets to authenticated;
grant select, insert, update, delete on table liabilities to authenticated;
grant select, insert, update, delete on table liability_payments to authenticated;

create policy "assets authenticated full access" on assets
  for all to authenticated using (true) with check (true);
create policy "liabilities authenticated full access" on liabilities
  for all to authenticated using (true) with check (true);
create policy "liability_payments authenticated full access" on liability_payments
  for all to authenticated using (true) with check (true);

notify pgrst, 'reload schema';
