-- ติดตามว่าซื้อทรัพย์สิน/จ่ายคืนหนี้ ใช้เงินจากบัญชีไหน เพื่อกระทบยอดบัญชีธนาคารได้ครบ
-- (ก่อนหน้านี้มีแค่ expenses.payment_account_id — assets/liability_payments ไม่มีช่องนี้ ทำให้เงินสดที่จ่ายจริง
--  ตอนซื้อทรัพย์สินหรือผ่อนคืนเจ้าของ ไม่โผล่ในรายงานแยกตามบัญชีเลย)
alter table assets add column payment_account_id uuid references payment_accounts(id);
alter table liability_payments add column payment_account_id uuid references payment_accounts(id);

notify pgrst, 'reload schema';
