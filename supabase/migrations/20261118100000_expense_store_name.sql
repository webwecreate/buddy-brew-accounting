-- ร้านค้าใน platform: vendor เก็บ "Shopee" (แพลตฟอร์ม/ที่ซื้อ) ส่วน store_name เก็บชื่อร้านใน platform นั้น
-- (เดิมรายการ Shopee ที่นำเข้าเก็บชื่อร้านไว้บรรทัดแรกของ note)
alter table expenses add column if not exists store_name text;

-- backfill: รายการที่นำเข้าจาก Shopee — ย้ายบรรทัดแรกของ note มาเป็น store_name แล้วตัดออกจาก note
update expenses
set store_name = nullif(btrim(split_part(note, E'\n', 1)), ''),
    note = nullif(btrim(substr(note, length(split_part(note, E'\n', 1)) + 2)), '')
where vendor = 'Shopee'
  and store_name is null
  and note like '%[นำเข้า Shopee 11-11 #%'
  and split_part(note, E'\n', 1) not like '[%';
