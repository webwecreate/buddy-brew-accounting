-- ระบบรายรับ-รายจ่าย: หมวดรายจ่าย, ช่องทางรายรับ, รายจ่าย (แยกรายไอเทม), รายรับ

create table expense_categories (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,              -- เช่น 'raw_materials', 'utilities'
  label_th text not null,
  group_key text not null,               -- 'depreciation' / 'overhead' / 'labor' / 'variable' / 'other'
  fixed_cost_model_monthly numeric,      -- ตัวเลขจาก Accounting/fixed_cost_v1.md ไว้เทียบยอดจริง, null = ไม่มีในโมเดล (ต้นทุนผันแปร)
  sort_order integer not null default 100,
  active boolean not null default true
);

create table income_channels (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,              -- 'grab' / 'in_store' / 'government'
  label_th text not null,
  note text,
  sort_order integer not null default 100,
  active boolean not null default true
);

-- expenses = หัวใบเสร็จ 1 ใบ (วันที่/ร้านค้า/รูป) ยอดรวม (amount) คำนวณจาก expense_items เสมอ ผ่าน trigger ด้านล่าง
-- ไม่มี category_id ที่ตารางนี้ เพราะแต่ละใบเสร็จอาจมีของหลายหมวด (เช่น ไป Makro ซื้อทั้งวัตถุดิบ+อุปกรณ์ทำความสะอาดในบิลเดียว) — หมวดหมู่อยู่ระดับ item แทน
create table expenses (
  id uuid primary key default gen_random_uuid(),
  expense_date date not null,
  amount numeric not null default 0,     -- sum(expense_items.line_total) ของใบนี้ อัปเดตอัตโนมัติผ่าน trigger, ห้าม insert/update ตรง
  vendor text,
  note text,
  payment_method text,                   -- cash / transfer / other
  receipt_photo_path text,               -- path ใน storage bucket 'receipts', null = ไม่มีรูป
  source text not null default 'manual', -- manual / ocr
  ocr_raw jsonb,                         -- raw response จาก receipt-ocr เก็บไว้ตรวจสอบย้อนหลัง/ปรับ prompt ทีหลัง
  ocr_confidence text,                   -- high / medium / low, null = ไม่ได้มาจาก ocr
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

-- รายการสินค้าแต่ละชิ้นในใบเสร็จ — จุดที่ OCR เติมให้ก่อน แล้วให้ staff แก้ไข/เพิ่ม/ลบเองก่อนบันทึกเสมอ
create table expense_items (
  id uuid primary key default gen_random_uuid(),
  expense_id uuid not null references expenses(id) on delete cascade,
  category_id uuid not null references expense_categories(id),
  item_name text not null,
  quantity numeric not null default 1,
  unit_price numeric not null,
  line_total numeric generated always as (quantity * unit_price) stored,
  sort_order integer not null default 0
);

create table income_entries (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references income_channels(id),
  entry_date date not null,
  kind text not null check (kind in ('expected', 'deposited')),  -- expected = ยอดขายตามระบบ, deposited = ยอดโอนเข้าจริง
  amount numeric not null,
  note text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

-- trigger: คำนวณ expenses.amount ใหม่ทุกครั้งที่ expense_items เปลี่ยน (insert/update/delete)
-- ใช้ trigger แทนให้ client คำนวณเองส่งมา เพราะครอบคลุมทุกทางที่แก้ item ในอนาคต (เช่น แก้ทีหลังผ่าน dashboard) ไม่ต้องพึ่ง client sync ให้ตรงเอง
create function recalc_expense_amount() returns trigger as $$
declare
  target_expense_id uuid;
begin
  target_expense_id := coalesce(new.expense_id, old.expense_id);
  update expenses
    set amount = (select coalesce(sum(line_total), 0) from expense_items where expense_id = target_expense_id)
    where id = target_expense_id;
  return null;
end;
$$ language plpgsql;

create trigger trg_recalc_expense_amount
  after insert or update or delete on expense_items
  for each row execute function recalc_expense_amount();

-- RLS: ต่างจาก members/points_transactions (ไม่มี policy = เข้าได้แค่ผ่าน edge function/service role)
-- ตารางนี้ staff ต้องกรอกตรงจากหน้าเว็บผ่าน supabase-js ได้เลย จึงเปิด policy ให้ authenticated ทำได้ทุกอย่าง
-- (โมเดลเดียวกับที่ระบบเดิมตัดสินใจไว้: login แล้ว = staff ที่เชื่อถือได้ ยังไม่มีตาราง role แยก)
alter table expense_categories enable row level security;
alter table income_channels enable row level security;
alter table expenses enable row level security;
alter table expense_items enable row level security;
alter table income_entries enable row level security;

grant select, insert, update, delete on table expense_categories to authenticated;
grant select, insert, update, delete on table income_channels to authenticated;
grant select, insert, update, delete on table expenses to authenticated;
grant select, insert, update, delete on table expense_items to authenticated;
grant select, insert, update, delete on table income_entries to authenticated;

create policy "expense_categories authenticated full access" on expense_categories
  for all to authenticated using (true) with check (true);
create policy "income_channels authenticated full access" on income_channels
  for all to authenticated using (true) with check (true);
create policy "expenses authenticated full access" on expenses
  for all to authenticated using (true) with check (true);
create policy "expense_items authenticated full access" on expense_items
  for all to authenticated using (true) with check (true);
create policy "income_entries authenticated full access" on income_entries
  for all to authenticated using (true) with check (true);

-- Seed จาก Accounting/fixed_cost_v1.md §5
-- owner_labor ใช้ "สูตร A ต่ำ" (17,000฿) เป็นค่าเริ่มต้น — แก้เป็นสูตรอื่นทีหลังได้ด้วย UPDATE ตัวเดียว ไม่ต้อง migration ใหม่
insert into expense_categories (key, label_th, group_key, fixed_cost_model_monthly, sort_order) values
  ('equipment_depreciation', 'ค่าเสื่อมอุปกรณ์', 'depreciation', 2374, 10),
  ('decor_depreciation', 'ค่าเสื่อมตกแต่ง', 'depreciation', 721, 20),
  ('utilities', 'ค่าน้ำ+ไฟ', 'overhead', 5500, 30),
  ('internet', 'ค่าอินเทอร์เน็ต', 'overhead', 400, 40),
  ('pos_subscription', 'ค่า POS (subscription)', 'overhead', 1000, 50),
  ('advertising', 'ค่าโฆษณา', 'overhead', 2500, 60),
  ('consumables_overhead', 'ค่าจิปาถะ/consumables', 'overhead', 3000, 70),
  ('owner_labor', 'ค่าแรงเจ้าของ', 'labor', 17000, 80),
  ('raw_materials', 'วัตถุดิบ (เมล็ดกาแฟ/นม/ไซรัป ฯลฯ)', 'variable', null, 90),
  ('packaging', 'บรรจุภัณฑ์ (แก้ว/ฝา/หลอด/ถุง)', 'variable', null, 100),
  ('cleaning_supplies', 'อุปกรณ์ทำความสะอาด', 'variable', null, 110),
  ('maintenance_repair', 'ซ่อมบำรุง', 'variable', null, 120),
  ('other', 'อื่นๆ', 'other', null, 130);

insert into income_channels (key, label_th, note, sort_order) values
  ('grab', 'Grab (เดลิเวอรี)', 'มี GP fee หักจาก Grab ก่อนโอนเข้าบัญชี', 10),
  ('in_store', 'หน้าร้าน', 'เงินสด/โอน', 20),
  ('government', 'โครงการรัฐ (เช่น คนละครึ่ง/ไทยช่วยไทย)', 'ชื่อโครงการยังไม่ยืนยันแน่ชัด — แก้ label_th ได้ทีหลัง', 30);

notify pgrst, 'reload schema';
