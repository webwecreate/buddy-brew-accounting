# Buddy Brew Accounting

> Hot memory — เก็บให้ LEAN เสมอ. detail อยู่ใน PROJECT_OVERVIEW.md ไม่ใช่ที่นี่

## เริ่มทุก session (ทำก่อนเสมอ)
1. อ่าน PROJECT_OVERVIEW.md — single source of truth ไม่ต้องไล่แชทเก่า
2. สรุป scope ของ task รอบนี้ให้ผู้ใช้ยืนยันก่อนลงมือ

## Conventions
- แก้ schema → migration ใหม่เสมอ (ห้ามแก้ไฟล์เก่า) → ตรวจว่า enable RLS แล้วต้องมี **policy จริง** ด้วย ไม่ใช่แค่ grant
- ค่าที่คำนวณจาก aggregation ของ child table ที่แก้ไขได้เรื่อยๆ (เช่น ยอดรวมใบเสร็จ, ยอดผ่อนสะสม) → ใช้ trigger เหมือน `recalc_expense_amount()`/`recalc_liability_paid_amount()`
- ค่าที่คำนวณล้วนๆ ไม่มี child table ให้ aggregate (เช่น ค่าเสื่อมราคาทรัพย์สิน) → คำนวณฝั่ง client ตอนแสดงผลเท่านั้น ไม่ต้อง store
- แท็บที่แสดงข้อมูลรวม (กระทบยอด/รายงาน/ทรัพย์สิน-หนี้) ต้อง reload ข้อมูลใหม่ทุกครั้งที่เปิดแท็บ (อย่าพึ่ง save handler อื่นเรียกให้เฉยๆ — เคยมีบั๊กนี้มาแล้ว)
- ก่อนจบ session: อัปเดต PROJECT_OVERVIEW.md (เช็คลิสต์สถานะ) แล้ว commit+push

## Stack
Supabase (Postgres + Edge Functions, project ref `xsokynhtoxktazlomsnx` — **ใช้ร่วมกับ repo `buddy-platform`/CRM, ฐานข้อมูลเดียวกันจริงๆ**) + GitHub Pages (`docs/`)

Migration apply ผ่าน `supabase db query --linked -f <file>` โดยตรง (ไม่ใช่ GitHub Integration เพราะผูกกับ `buddy-platform` ไปแล้ว, 1 repo ต่อ 1 project) — ส่วน Edge Functions auto-deploy ผ่าน GitHub Actions ได้ปกติ (ใช้ access token ไม่ใช่ DB password)

## Never
- ห้าม commit service_role key / secret key ลง git เด็ดขาด
- ห้ามตั้งชื่อตารางแบบทั่วไปเกินไปโดยไม่เช็ค schema ของ CRM (`buddy-platform`) ก่อน เพราะอยู่ Postgres เดียวกัน
