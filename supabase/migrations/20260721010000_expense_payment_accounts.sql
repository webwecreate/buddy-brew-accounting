-- บัญชี/ช่องทางที่ใช้จ่ายเงินออกจริง — เพิ่มเพื่อให้กระทบยอดรายจ่ายได้ไม่สับสน
-- (ต่างจาก income_channels ที่เป็น "ช่องทางขาย" เช่น Grab/หน้าร้าน/รัฐ — อันนี้คือ "บัญชีที่เงินไหลออกจริง"
-- ซึ่งร้านใช้บัญชีรับเงินเดิมเป็นบัญชีหมุนเวียนจ่ายด้วย เลยมีชื่อคล้ายกันแต่เป็นคนละมิติ)

create table payment_accounts (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  label_th text not null,
  note text,
  sort_order integer not null default 100,
  active boolean not null default true
);

alter table payment_accounts enable row level security;
grant select, insert, update, delete on table payment_accounts to authenticated;
create policy "payment_accounts authenticated full access" on payment_accounts
  for all to authenticated using (true) with check (true);

insert into payment_accounts (key, label_th, note, sort_order) values
  ('scb', 'SCB (ไทยพาณิชย์)', 'รับหน้าร้าน + LINEMAN', 10),
  ('ktb', 'KTB (กรุงไทย)', 'รับโครงการรัฐ (60/40 / คนละครึ่ง)', 20),
  ('krungsri', 'กรุงศรี', 'รับ Grab', 30),
  ('cash', 'เงินสด', null, 40),
  ('owner_advance', 'เงินส่วนตัวเจ้าของ (ทดรองจ่าย)', 'เลือกอันนี้บ่อยๆ ควรไปสร้างรายการหนี้สินคู่กันในแท็บทรัพย์สิน/หนี้ด้วย', 50);

-- แทนที่ payment_method (text ทั่วไป cash/transfer/other) ด้วย payment_account_id ที่เจาะจงบัญชีจริง
-- ยังไม่มีข้อมูลจริงในระบบเลย (ยังไม่ deploy) จึง drop คอลัมน์เดิมได้เลยไม่ต้อง migrate ข้อมูล
alter table expenses drop column payment_method;
alter table expenses add column payment_account_id uuid references payment_accounts(id);

notify pgrst, 'reload schema';
