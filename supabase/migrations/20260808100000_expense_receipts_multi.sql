-- รองรับแนบสลิป/เอกสารได้หลายรูปต่อ 1 ใบเสร็จ (เดิม expenses.receipt_photo_path เก็บได้แค่รูปเดียว)
-- expenses.receipt_photo_path ยังคงอยู่เหมือนเดิมสำหรับรูปที่มาจากช่อง OCR (ยังจำกัดรูปเดียวตามเดิม ไม่กระทบข้อมูลเก่า)
-- ตารางนี้ใช้เก็บรูปที่แนบเพิ่มเติมจากช่อง "แนบรูปสลิป (หลักฐาน)" ในฟอร์มกรอกเอง ซึ่งเลือกได้หลายไฟล์

create table expense_receipts (
  id uuid primary key default gen_random_uuid(),
  expense_id uuid not null references expenses(id) on delete cascade,
  photo_path text not null,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

alter table expense_receipts enable row level security;
grant select, insert, update, delete on table expense_receipts to authenticated;
create policy "expense_receipts authenticated full access" on expense_receipts
  for all to authenticated using (true) with check (true);

notify pgrst, 'reload schema';
