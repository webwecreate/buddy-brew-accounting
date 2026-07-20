-- Private storage bucket สำหรับรูปใบเสร็จรายจ่าย
insert into storage.buckets (id, name, public)
values ('receipts', 'receipts', false)
on conflict (id) do nothing;

-- storage.objects เปิด RLS อยู่แล้วโดย platform — เพิ่ม policy เฉพาะ bucket นี้
-- โมเดลเดียวกับตาราง accounting: login แล้ว (authenticated) = staff ที่เชื่อถือได้ ไม่มี anon access
create policy "receipts authenticated select" on storage.objects
  for select to authenticated using (bucket_id = 'receipts');
create policy "receipts authenticated insert" on storage.objects
  for insert to authenticated with check (bucket_id = 'receipts');
create policy "receipts authenticated update" on storage.objects
  for update to authenticated using (bucket_id = 'receipts');
create policy "receipts authenticated delete" on storage.objects
  for delete to authenticated using (bucket_id = 'receipts');
