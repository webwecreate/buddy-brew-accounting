-- แนบรูปสลิปหลักฐานการจ่ายหนี้ได้ทีละงวด (แต่ละ liability_payments 1 แถว = จ่ายคืนหนี้ 1 ครั้ง)
-- pattern เดียวกับ expense_receipts/asset_receipts — ใช้บัคเก็ต 'receipts' เดิม แยก path prefix เป็น liability-payments/...

create table liability_payment_receipts (
  id uuid primary key default gen_random_uuid(),
  liability_payment_id uuid not null references liability_payments(id) on delete cascade,
  photo_path text not null,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

alter table liability_payment_receipts enable row level security;
grant select, insert, update, delete on table liability_payment_receipts to authenticated;
create policy "liability_payment_receipts authenticated full access" on liability_payment_receipts
  for all to authenticated using (true) with check (true);

notify pgrst, 'reload schema';
