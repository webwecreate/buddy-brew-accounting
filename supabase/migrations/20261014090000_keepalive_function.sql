-- ฟังก์ชันเบาๆ ให้ GitHub Actions (keepalive.yml) เรียกเป็นระยะ กัน Supabase Free plan หยุดโปรเจกต์อัตโนมัติเมื่อไม่มีการใช้งานนาน (7 วัน)
-- คืนแค่เวลาปัจจุบัน ไม่แตะตาราง/ไม่เปิดเผยข้อมูลการเงินใดๆ จึงเปิดให้ anon เรียกได้โดยไม่ขัดหลักการ "ไม่มี anon access ที่ตาราง"
-- ใช้ชื่อเฉพาะ (accounting_keepalive) เพราะอยู่ DB เดียวกับ CRM repo

create or replace function public.accounting_keepalive()
returns timestamptz
language sql
stable
as $$ select now() $$;

grant execute on function public.accounting_keepalive() to anon, authenticated;

notify pgrst, 'reload schema';
