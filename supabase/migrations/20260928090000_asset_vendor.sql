-- เพิ่มช่อง "ซื้อจากร้าน/ผู้ขาย" ให้ทรัพย์สิน — เดิมมีแค่ liabilities.creditor_name ที่เก็บชื่อผู้ขายได้ (กรณีเป็นหนี้)
-- แต่ทรัพย์สินที่ซื้อสดไม่มีช่องเก็บชื่อร้านค้าเลย
alter table assets add column vendor text;

notify pgrst, 'reload schema';
