-- แนบรูปสลิป/ใบเสร็จหลักฐานการซื้อทรัพย์สินได้ (หลายรูปต่อ 1 ทรัพย์สิน) — ใช้ pattern เดียวกับ expense_receipts
-- เก็บไฟล์ในบัคเก็ต 'receipts' เดิม (private, policy authenticated ครอบคลุมทุก path อยู่แล้ว ไม่ต้องเพิ่ม policy ใหม่)
-- แค่ใช้ path prefix ต่างกัน (assets/... แทน YYYY-MM/...) เพื่อแยกจากรูปสลิปรายจ่าย

create table asset_receipts (
  id uuid primary key default gen_random_uuid(),
  asset_id uuid not null references assets(id) on delete cascade,
  photo_path text not null,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

alter table asset_receipts enable row level security;
grant select, insert, update, delete on table asset_receipts to authenticated;
create policy "asset_receipts authenticated full access" on asset_receipts
  for all to authenticated using (true) with check (true);

notify pgrst, 'reload schema';
