# Buddy Brew Accounting — Project Overview

สรุปรวมทุกอย่างที่ตัดสินใจไว้ในการวางแผน+สร้างระบบบัญชีร้าน **เป็น single source of truth**
ถ้าเปิดแชทใหม่ (context เต็ม หรือแยก session) ให้อ่านไฟล์นี้ก่อนเสมอ ไม่ต้องไล่อ่านแชทเก่า

---

## 1. เป้าหมาย

ระบบบันทึกรายรับ-รายจ่ายของร้าน Buddy Brew ที่เข้าถึงได้ทุกที่ (ไม่ต้องเปิดคอมเครื่องใดเครื่องหนึ่งทิ้งไว้) แทนที่การจดใน Spendee + Excel แบบเดิม เป้าหมายไม่ใช่แค่บันทึกกระแสเงินสด แต่ให้เห็น**ฐานะการเงินจริง**ของร้าน: มีทรัพย์สินอะไรบ้าง ค่าเสื่อมไปเท่าไหร่ และ**เป็นหนี้ใครอยู่เท่าไหร่** (รวมถึงกรณีเจ้าของออกเงินส่วนตัวไปก่อนแล้วร้านยังไม่ได้คืน — ต้อง track แยกเป็นรายเจ้าหนี้ ไม่ปนกับกำไรปกติ)

---

## 2. Tech stack

| ส่วน | ใช้อะไร | เหตุผล |
|---|---|---|
| Backend | Supabase (Postgres + Data API + Edge Functions) | Table Editor ใช้งานง่าย ไม่ต้องเขียน backend เอง |
| Hosting หน้าเว็บ | GitHub repo (public) + GitHub Pages (โฟลเดอร์ `/docs`) | แก้โค้ด → commit → push → deploy อัตโนมัติ |
| OCR ใบเสร็จ | Anthropic Claude API (Haiku 4.5, vision) เรียกผ่าน Edge Function | อ่านรายการสินค้าจากรูปใบเสร็จ แปลงเป็น JSON โครงสร้างให้พร้อม prefill ฟอร์ม |
| Frontend | Static HTML/JS ล้วน ไม่มี framework/build step | เครื่อง dev ไม่มี Node.js ติดตั้ง, deploy ง่ายเหมือน CRM repo |

---

## 3. Account / ID ทั้งหมด (ของจริง ใช้อ้างอิงตรงๆ)

| อะไร | ค่า |
|---|---|
| Supabase Project URL | `https://xsokynhtoxktazlomsnx.supabase.co` |
| Supabase Project ref | `xsokynhtoxktazlomsnx` |
| Supabase publishable key | `sb_publishable_r-BdEYs8q61oSQKv_qJpPw_Xh5BPgRa` (ปลอดภัยเปิดเผยได้ ถูกออกแบบมาให้ public) |
| GitHub repo | `https://github.com/webwecreate/buddy-brew-accounting` (Public) |
| GitHub Pages URL | `https://webwecreate.github.io/buddy-brew-accounting/accounting.html` |

**⚠️ Supabase project นี้ใช้ร่วมกับ repo `buddy-platform` (CRM/ระบบสมาชิก)** — เป็นฐานข้อมูล Postgres เดียวกันจริงๆ ไม่ใช่แค่ organization เดียวกัน ตารางของสองระบบอยู่ใน schema `public` เดียวกันหมด (ตอนนี้ไม่ชนกัน: CRM มี `members`/`menu_items`/`points_transactions`/ฯลฯ ส่วนระบบนี้มี `expenses`/`assets`/`liabilities`/ฯลฯ) — **เช็คชื่อตารางของ CRM ก่อนเพิ่มตารางใหม่เสมอ**

**ห้ามใส่ในไฟล์นี้/ในโค้ด**: service_role key / secret key ของ Supabase, Anthropic API key — เก็บเป็น Supabase secret เท่านั้น ไม่ commit ลง git เด็ดขาด

---

## 4. กลไก Deploy (ต่างจาก CRM repo — สำคัญ)

- **Migrations** (`supabase/migrations/*.sql`): Supabase GitHub Integration ผูกกับ repo `buddy-platform` ไปแล้ว (1 repo ต่อ 1 project) จึง repo นี้**ไม่ auto-apply migration ตอน push** ต้อง apply ด้วย `supabase db query --linked -f <file>` ผ่าน Supabase CLI โดยตรง (ติดตั้งแบบ standalone binary ที่ `C:\Users\LegendN\tools\supabase-cli\supabase.exe` ไม่ผ่าน npm เพราะเครื่องนี้ไม่มี Node.js)
- **Edge Functions** (`supabase/functions/*`): auto-deploy ผ่าน GitHub Actions (`.github/workflows/deploy-functions.yml`) เหมือน CRM — ใช้ `SUPABASE_ACCESS_TOKEN` เป็น GitHub secret
- **หน้าเว็บ** (`docs/*.html`): GitHub Pages serve จาก `/docs` อัตโนมัติทุกครั้งที่ push (หลัง enable Pages ใน repo settings ครั้งแรก)
- CLI ทำงานผ่าน personal access token ที่ login ไว้แล้ว (`supabase login --token`) — ไม่ต้องใช้ database password เลย เพราะใช้ `db query --linked`/`functions deploy` ที่ผ่าน Management API ไม่ใช่ direct Postgres connection

---

## 5. Architecture

```
พนักงาน/เจ้าของร้าน (มือถือ/คอม) ──▶ docs/accounting.html (GitHub Pages)
                                          │
                                          ├─▶ Supabase Data API (ตรง, ผ่าน RLS)
                                          │     expenses, expense_items, income_entries,
                                          │     assets, liabilities, liability_payments
                                          │
                                          └─▶ Edge Function receipt-ocr ──▶ Anthropic Claude API
                                                (auth-gated, ใช้ตอนถ่ายรูปใบเสร็จเท่านั้น)
```

- หน้าเว็บเรียก Supabase ตรงผ่าน `supabase-js` (CDN) ด้วย session ของ staff ที่ login แล้ว ไม่ผ่าน Edge Function สำหรับ CRUD ปกติ (ต่างจาก CRM ที่บาง endpoint บังคับผ่าน Edge Function)
- มีแค่จุดเดียวที่ผ่าน Edge Function: OCR ใบเสร็จ (เพราะต้องเรียก Anthropic API ด้วย secret key ที่ client เห็นไม่ได้)

---

## 6. โครงสร้างไฟล์ในโปรเจกต์

```
buddy-brew-accounting/
├── CLAUDE.md                        ← hot memory สั้นๆ
├── PROJECT_OVERVIEW.md              ← ไฟล์นี้
├── docs/
│   └── accounting.html              ← หน้าเว็บเดียว ทุกแท็บอยู่ในนี้
├── supabase/
│   ├── config.toml                  ← project_id ผูก Supabase project
│   ├── functions/
│   │   └── receipt-ocr/             ← เรียก Claude อ่านใบเสร็จ
│   └── migrations/
│       ├── 20260720090000_accounting_tables.sql       ← expense_categories, income_channels, expenses, expense_items, income_entries
│       ├── 20260720091000_accounting_receipts_bucket.sql ← storage bucket 'receipts'
│       ├── 20260720092000_assets_liabilities_tables.sql  ← assets, liabilities, liability_payments
│       ├── 20260721010000_expense_payment_accounts.sql   ← payment_accounts, expenses.payment_account_id (แทน payment_method เดิม)
│       ├── 20260721020000_products_conversion.sql        ← products, expense_items.product_id
│       └── 20260808100000_expense_receipts_multi.sql      ← expense_receipts (แนบสลิปได้หลายรูปต่อใบเสร็จ)
└── .github/workflows/deploy-functions.yml  ← auto-deploy edge functions
```

---

## 7. Database schema

### `expense_categories` — หมวดรายจ่าย (seed จาก `Accounting/fixed_cost_v1.md`)
`key, label_th, group_key (depreciation/overhead/labor/variable/other), fixed_cost_model_monthly (null = ไม่มีในโมเดล), sort_order, active`

### `income_channels` — ช่องทางรายรับ (seed: grab, in_store, government)
`key, label_th, note, sort_order, active`

`government.label_th` แก้เป็น **"ไทยช่วยไทย พลัส"** (ชื่อโครงการรัฐจริง พบจากไฟล์ POS จริง — ตอน seed แรกใส่ placeholder ไว้เพราะยังไม่รู้ชื่อเต็ม) แก้ผ่าน UPDATE ตรงๆ ผ่าน CLI ไม่ต้องออก migration ใหม่ (ตามธรรมเนียมเดียวกับที่แก้ `owner_labor` seed มาก่อน)

### `expenses` — หัวใบเสร็จ 1 ใบ
`expense_date, amount (คำนวณอัตโนมัติจาก expense_items ผ่าน trigger ห้าม insert/update ตรง), vendor, note, payment_account_id FK, receipt_photo_path, source (manual/ocr), ocr_raw, ocr_confidence, created_by, created_at`

ไม่มี `category_id` ที่ตารางนี้เพราะ 1 ใบเสร็จอาจมีของหลายหมวด — หมวดหมู่อยู่ระดับ item แทน

### `payment_accounts` — บัญชี/ช่องทางที่เงินไหลออกจริงตอนจ่าย (seed: scb, ktb, krungsri, cash, owner_advance)
`key, label_th, note, sort_order, active` — คนละมิติกับ `income_channels` (channel = ขายผ่านช่องทางไหน, account = เงินไหลออกจากบัญชีไหนจริง) แม้ตอนนี้จะ map กันเกือบ 1:1 (SCB↔หน้าร้าน/LINEMAN, KTB↔รัฐ, กรุงศรี↔Grab) เพราะร้านใช้บัญชีรับเงินเดิมเป็นบัญชีหมุนเวียนจ่ายด้วย เพิ่มเพื่อกระทบยอดรายจ่ายได้ไม่สับสน — ถ้าเลือก `owner_advance` บ่อยๆ ควรไปสร้างรายการคู่กันในตาราง `liabilities` (creditor_type='owner') ด้วย ไม่ auto-link ให้ (ยังต้องทำมือ)

### `expense_items` — รายการสินค้าแต่ละชิ้นในใบเสร็จ
`expense_id FK, category_id FK, item_name, quantity, unit_price, line_total (generated column = quantity × unit_price), sort_order`

trigger `trg_recalc_expense_amount` → คำนวณ `expenses.amount` ใหม่ทุกครั้งที่ `expense_items` เปลี่ยน

### `income_entries` — รายรับ
`channel_id FK, entry_date, kind (expected/deposited), amount, note, created_by, created_at`

### `assets` — ทรัพย์สินของร้าน
`name, category (equipment/decor), purchase_price, purchase_date, useful_life_months (default 24 ตาม fixed_cost_v1.md), status (active/disposed), disposed_date, note, created_by, created_at`

ค่าเสื่อม**ไม่เก็บเป็นคอลัมน์** คำนวณฝั่ง client ตอนแสดงผล (`assetDepreciation()` ใน accounting.html) เพราะเป็นฟังก์ชันล้วนไม่มี child table ให้ aggregate

### `liabilities` — หนี้สินแต่ละก้อน
`creditor_type (vendor/owner/bank/other), creditor_name (ชื่อ vendor หรือชื่อเจ้าของที่ออกเงิน — จุดสำคัญของ feature นี้), asset_id FK (ไม่บังคับ), original_amount, paid_amount (trigger คำนวณจาก liability_payments), start_date, status (open/paid_off, auto-flip โดย trigger), note, created_by, created_at`

### `liability_payments` — ประวัติจ่ายหนี้แต่ละงวด
`liability_id FK, payment_date, amount, note, created_by, created_at`

trigger `trg_recalc_liability_paid_amount` → คำนวณ `liabilities.paid_amount` ใหม่ทุกครั้งที่มีการจ่ายเพิ่ม/แก้/ลบ + auto-flip status เป็น `paid_off` เมื่อจ่ายครบ (กลับเป็น `open` ถ้าแก้ยอดลดลงทีหลัง)

**เหตุผลที่ต้อง track เจ้าหนี้แยกประเภท**: ผ่อนหมดกับ vendor ไม่ได้แปลว่าร้านหมดหนี้เสมอไป — ถ้าเงินที่โปะ vendor แต่ละงวดมาจากกระเป๋าเจ้าของเอง (ไม่ใช่รายได้ร้าน) ร้านจะกลายเป็นหนี้เจ้าของคนนั้นแทน ต้องทยอยคืนจากกำไรจริง แยกจากการแบ่งกำไรปกติระหว่างเจ้าของ 2 คน

### `expense_receipts` — รูปสลิป/เอกสารหลักฐานเพิ่มเติม (แนบได้หลายรูปต่อ 1 ใบเสร็จ)
`expense_id FK (on delete cascade), photo_path, created_by, created_at`

`expenses.receipt_photo_path` เดิม (คอลัมน์เดียว) ยังใช้อยู่สำหรับรูปที่มาจากช่อง OCR ด้านบนสุด (ยังจำกัดรูปเดียวเหมือนเดิม ไม่กระทบข้อมูลเก่า) — ส่วนช่อง "แนบรูปสลิป/เอกสาร (หลักฐาน)" ในฟอร์มกรอกเอง เลือกได้หลายไฟล์พร้อมกัน แต่ละไฟล์ insert เป็น 1 แถวในตารางนี้ ฝั่ง UI (แท็บรายการรายจ่าย) รวมรูปจากทั้งสองแหล่งเข้าด้วยกันตอนแสดงปุ่ม "ดูรูปสลิป"

### `products` — ชื่อสินค้ากลาง + หน่วยแปลง
`name (unique), category_id FK, purchase_unit_label (เช่น 'แพ็ค (6 ขวด)'), usage_unit_label (เช่น 'ขวด'/'กรัม'/'มล.'), conversion_qty (1 หน่วยซื้อ = กี่หน่วยใช้งาน, > 0), note, active, created_by, created_at`

`expense_items.product_id` (FK, nullable, `on delete set null`) — ผูก item เข้ากับสินค้าได้ ไม่บังคับตอนบันทึก แก้ปัญหา 2 เรื่องพร้อมกัน: (1) ชื่อสินค้าพิมพ์/OCR ไม่ตรงกันทุกครั้ง (2) คำนวณราคาต่อหน่วยใช้งานจริงได้ (`unit_price ÷ conversion_qty`) โดยที่ `expense_items.quantity`/`unit_price` ยังหมายถึงหน่วยซื้อเหมือนเดิมทุกอย่าง ไม่ต้องแก้ข้อมูลเก่า

**Auto-link**: ตอนบันทึกรายจ่าย ถ้า `item_name.trim()` ตรงกับ `products.name` แบบ exact match → ผูก `product_id` ให้อัตโนมัติ (ส่วนใหญ่จะ fire ตอน "กรอกเอง" ที่มี datalist ช่วยเลือกชื่อเดิม มากกว่าตอน OCR ที่มักอ่านชื่อคนละแบบ) — รายการที่ไม่ตรงยังบันทึกได้ปกติ แค่ยังไม่ผูก ไปผูกทีหลังผ่านแท็บ "สินค้า" (Card 2: รายชื่อที่ยังไม่ผูก → เลือกหลายชื่อ + bulk link เข้าสินค้าเดียวกัน)

---

## 8. RLS model

ทุกตารางในระบบนี้ (ไม่มีข้อยกเว้น): เปิด RLS + policy `for all to authenticated using (true) with check (true)` — โมเดล "login แล้วผ่าน Supabase Auth = staff ที่เชื่อถือได้" ยังไม่มีตาราง role แยก (ถ้ามี staff/role table ในอนาคตค่อยจำกัดสิทธิ์ละเอียดขึ้น)

**ต่างจาก CRM repo ตรงนี้**: CRM มี `menu_items`/`bean_options` ที่เปิดให้ `anon` อ่านได้ (เพราะ Staff Panel ยังไม่มี login ตอนนั้น) — **ระบบนี้ไม่มีข้อยกเว้นแบบนั้นเลย ไม่มี anon access ที่ตารางไหนทั้งสิ้น** เพราะเป็นข้อมูลการเงินล้วนๆ (ทดสอบยืนยันแล้วว่า anon key เจอ "permission denied" ทุกตาราง)

Storage bucket `receipts` (private) ก็ใช้โมเดลเดียวกัน — policy จำกัดที่ `authenticated` เท่านั้น

---

## 9. แท็บ / UI breakdown (`docs/accounting.html`)

หน้าเดียว ไม่มี router, toggle ด้วย `.tabbar button[data-tab]` + `#tab-<name>` — ทุกแท็บที่โชว์ข้อมูลรวม (recon/report/assets) reload ข้อมูลใหม่ตอนเปิดแท็บเสมอ (ดูข้อ 11 บั๊กที่เจอ)

1. **เพิ่มรายจ่าย** — 2 ทาง: (a) ถ่ายรูปใบเสร็จผ่านช่องบนสุด → OCR (`receipt-ocr` function) prefill รายการสินค้าเป็นแถวๆ (ชื่อ/จำนวน/ราคา/หมวด) → แก้ไขได้ทุกช่องก่อนบันทึกเสมอ หรือ (b) กด "กรอกเอง" ข้าม OCR ทั้งหมด — ทั้งสองทางมีช่อง**แนบรูปสลิป/เอกสารเป็นหลักฐาน**แยกต่างหากก่อนปุ่มบันทึก (ไม่เรียก OCR ซ้ำ ไม่เสียค่า API เพิ่ม แค่ย่อรูปแล้วอัปโหลดตอนบันทึก, ไม่บังคับ `capture` เพื่อให้เลือกจากอัลบั้ม/คลังรูปได้ ไม่ใช่เปิดกล้องอย่างเดียว, เลือกได้หลายไฟล์พร้อมกัน — เก็บลง `expense_receipts`) → เลือก "จ่ายจากบัญชี" (SCB/KTB/กรุงศรี/เงินสด/เงินส่วนตัวเจ้าของ) → insert `expenses` + `expense_items` + อัปโหลดรูปเข้า bucket `receipts` (private) — `expenses.source` บันทึกตามจริงว่ารูปมาจาก OCR หรือแนบเองแยกจากการกรอกฟอร์ม
2. **รายการรายจ่าย** — ledger/บัญชีแยกประเภท (ต่างจาก "รายงานเดือน" ที่เป็นสรุปภาพใหญ่): browse รายการรายจ่ายแบบรายไอเทม, ปุ่ม preset วันนี้/เดือนนี้/เดือนที่แล้ว หรือกรองเองตามช่วงวันที่/หมวดหมู่/บัญชีที่จ่าย, จัดกลุ่มตามวันที่, ปุ่ม **"ดูรูปสลิป"** ต่อรายการ (ถ้ามีรูปแนบ — สร้าง signed URL ชั่วคราวจาก bucket private แล้วเปิดดู เพราะ bucket ไม่มี public access — **หมายเหตุ**: รูปผูกกับ "ใบเสร็จ" ไม่ใช่ "ไอเทม" ถ้าใบเสร็จเดียวมีหลายไอเทม การ์ดของทุกไอเทมในใบเสร็จนั้นจะโชว์ปุ่มรูปชุดเดียวกันซ้ำกัน ไม่ใช่รูปคนละใบ — เลขกำกับ "รูป 1/2/3" ขึ้นเฉพาะตอนใบเสร็จนั้นมีไฟล์แนบมากกว่า 1 ไฟล์จริงๆ), ปุ่ม **"แก้ไขรายละเอียด"** ต่อไอเทม (แก้ชื่อสินค้า/จำนวน/ราคา/หมวดหมู่ — ใช้ตอนกรอกผิดหรือ OCR อ่านผิด ไม่ต้องลบแล้วเพิ่มใหม่), ปุ่ม **"แก้ไข"** ที่บรรทัดบัญชี/ร้านค้า (แก้ vendor + จ่ายจากบัญชี ระดับใบเสร็จ, มี autocomplete จากประวัติ vendor เดิม), ปุ่ม **"แก้ไขการผูก"** ต่อรายการ (เปิด dropdown เลือกสินค้าใหม่ หรือเลือก "— ไม่ผูก —" เพื่อยกเลิกการผูก — ใช้แก้เวลาผูกสินค้าผิด เพราะเครื่องมือกวาด duplicate ในแท็บ "สินค้า" ดูแลได้แค่รายการที่ยังไม่ผูกเท่านั้น ไม่ครอบคลุมรายการที่ผูกผิดไปแล้ว), ลบรายการได้ (ลบ item สุดท้ายของใบเสร็จแล้ว auto ลบ header ที่ว่างเปล่าทิ้งด้วย)
3. **เพิ่มรายรับ** — เลือกช่องทาง + ประเภทยอด (ตามระบบ/โอนเข้าจริง) → insert `income_entries` · มี 2 ตัวช่วยนำเข้าในตัว:
   - **นำเข้าจาก Bank Statement** (CSV ผ่าน PapaParse, Excel ผ่าน SheetJS — แยก parser 2 ทางเพราะ SheetJS auto-detect วันที่ในข้อความ CSV ผิด ต้องให้ CSV ได้ raw string เสมอแล้วพาร์สวันที่เองตามฟอร์แมตที่เลือก DD/MM/YYYY เป็นค่า default): เลือกช่องทาง default → อัปโหลดไฟล์ → จับคู่คอลัมน์ (วันที่/จำนวนเงิน/คำอธิบาย) + เลือกรูปแบบวันที่ → พรีวิวก่อนนำเข้า (กรองแถวไม่เป็นบวกออกอัตโนมัติ, เช็คซ้ำกับ `(entry_date, amount)` ที่มีอยู่แล้วในช่องทางเดียวกัน ติดป้าย "อาจซ้ำ" auto-uncheck, แก้ช่องทางต่อแถวได้) → bulk insert เป็น `kind='deposited'` ทั้งหมด
   - **นำเข้ายอดขายจาก POS** (ยอดสรุปแยกตามประเภทการชำระเงิน — ใช้ CSV/Excel infra เดียวกับ bank statement): ตั้งจำนวนบรรทัดที่ต้อง skip ก่อนถึง header จริง (รองรับไฟล์ที่มี comment line นำหน้า) → อัปโหลดไฟล์ → จับคู่คอลัมน์ (ประเภทการชำระเงิน/วิธีบันทึก ไม่บังคับ/จำนวนเงิน — เดา default ให้จาก keyword ในชื่อ header) → ตั้งวันที่ของรายงาน (ค่าเดียวทั้งไฟล์ เพราะเป็นยอดสรุปของช่วงเวลาเดียว) → พรีวิว (กรองแถว "Total" ทิ้งอัตโนมัติ, เดาช่องทางต่อแถวจาก keyword ในชื่อประเภทการชำระเงิน: มี "grab"→Grab, มี "ไทยช่วยไทย"/"รัฐ"→รัฐ, อื่นๆ→หน้าร้าน, แก้เองได้ทุกแถว, remark prefill อธิบายที่มา) → bulk insert เป็น `kind='expected'` ทั้งหมด (แยกแถวตามต้นฉบับ POS ไม่รวมยอด เพื่อให้ remark ต่อ line item ได้ตรงตามที่ขอ)
4. **กระทบยอด** — เลือกเดือน → เทียบยอดตามระบบ vs โอนเข้าจริง แยก 3 ช่องทาง แต่ละการ์ดมีปุ่ม "ดูรายการ (N)" ขยาย/ยุบตารางรายการ `income_entries` ของช่องทาง+เดือนนั้นเป็นรายบรรทัด (วันที่/ประเภท/จำนวนเงิน/remark แก้ไขได้ inline ผ่าน `income_entries.note`/ปุ่มลบ) — ตอบโจทย์ "ดูว่ายอดไหนหายไปอย่างไร" โดยไม่ต้องออกจากหน้ากระทบยอด
5. **รายงานเดือน** — สรุปรายจ่ายจริงตามหมวดเทียบ cost model, รายจ่ายแยกตามบัญชีที่จ่าย, รายรับ-รายจ่ายรวม, มูลค่าทรัพย์สินสุทธิ, หนี้สินคงค้างแยกตามเจ้าหนี้
6. **ทรัพย์สิน/หนี้** — 2 การ์ด: (a) เพิ่ม/ดูทรัพย์สิน พร้อมค่าเสื่อมสะสม+มูลค่าคงเหลือคำนวณสด (b) เพิ่ม/ดูหนี้สิน พร้อมบันทึกจ่ายเป็นงวดๆ ต่อรายการ
7. **สินค้า** — 2 การ์ด: (a) เพิ่ม/ดูสินค้า พร้อมหน่วยซื้อ→หน่วยใช้งาน+อัตราแปลง+ราคาล่าสุดต่อหน่วยใช้งาน (คำนวณจาก expense_item ล่าสุดที่ผูกไว้) (b) รายชื่อรายจ่ายที่ยังไม่ผูกกับสินค้า (group by ชื่อ เรียงตัวอักษร) เลือกหลายชื่อ + ผูกเข้าสินค้าเดียวกันทีเดียว

---

## 10. สถานะปัจจุบัน

- [x] Phase 1: schema รายรับ-รายจ่าย + storage bucket + OCR function + แท็บหลัก — build/deploy/ทดสอบจริงผ่านหมด, **push แล้ว, GitHub Pages เปิดใช้งานแล้ว** live ที่ `accounting.html`
- [x] Phase 2: assets/liabilities + trigger คำนวณหนี้คงเหลืออัตโนมัติ — ทดสอบ scenario จริง (เครื่องชงกาแฟ 50,000 เป็นหนี้เจ้าของ ค่อยๆ จ่ายจนหมด) push แล้ว
- [x] Phase 3: `payment_accounts` (SCB/KTB/กรุงศรี/เงินสด/เงินส่วนตัวเจ้าของ) แทน `payment_method` เดิม + รายงานแยกตามบัญชี — push แล้ว
- [x] แท็บ "รายการรายจ่าย" (ledger: กรอง/ดู/ลบรายไอเทม) — push แล้ว
- [x] แก้บั๊กมือถือ (ตารางล้นขอบจอ) — push แล้ว, ทดสอบที่ 320px/360px viewport ผ่าน
- [x] Phase 4: `products` + หน่วยแปลง + auto-link + เครื่องมือกวาดชื่อซ้ำ — build/push แล้ว ทดสอบจริงผ่านหมด (auto-link ตอนบันทึก, bulk-link ชื่อที่ไม่ตรง, คำนวณราคาต่อหน่วยใช้งานถูกต้อง) + แก้บั๊ก ledger โชว์ชื่อดิบแทนชื่อสินค้าที่ผูกแล้ว — push แล้ว
- [x] Phase 5: นำเข้ารายรับย้อนหลังจาก bank statement (CSV/Excel) ในแท็บเพิ่มรายรับ — build เสร็จ เจอ+แก้บั๊กจริงระหว่างทดสอบ (SheetJS auto-detect วันที่ผิดสำหรับ CSV ใช้ PapaParse แทน) ทดสอบ column mapping/date parsing/dedup ผ่านหมด
- [x] Phase 5b: นำเข้ายอดขายจาก POS (kind='expected') + แท็บกระทบยอดดูรายละเอียดเป็นรายการ (แก้ remark/ลบได้) + แก้ label `income_channels.government` เป็น "ไทยช่วยไทย พลัส" — ทดสอบกับไฟล์ POS จริงของร้านผ่านหมด (skip-line, กรอง Total, เดาช่องทางถูกทุกแถว, ยอดรวมตรงกับไฟล์ต้นฉบับ 102,812.50, แก้ remark/ลบใน UI persist จริง)
- [x] แนบรูปสลิปเป็นหลักฐานได้ทั้ง OCR/กรอกเอง (ไม่ผูกกับการเรียก OCR อีกต่อไป) + ปุ่ม "ดูรูปสลิป" ในแท็บรายการรายจ่าย (signed URL จาก private bucket) + ปุ่ม preset "เดือนที่แล้ว" — ทดสอบผ่าน throwaway account: แนบรูปแบบกรอกเองไม่เรียก OCR, `expenses.source='manual'` ถูกต้อง, อัปโหลดขึ้น bucket จริง, เปิดดูรูปผ่าน signed URL สำเร็จ (200 image/jpeg), preset เดือนที่แล้วคำนวณช่วงวันที่ถูกต้อง
- [x] ปุ่ม "แก้ไขการผูก" ในแท็บรายการรายจ่าย — แก้ไข/ยกเลิกการผูกสินค้าของรายการที่ผูกไปแล้ว (เดิมมีแค่เครื่องมือกวาดรายการที่ยังไม่ผูก) — ทดสอบผ่าน throwaway account: unlink สำเร็จ (product_id → null), relink ไปสินค้าอื่นสำเร็จ
- [x] ปุ่ม "แก้ไขรายละเอียด" (ชื่อสินค้า/จำนวน/ราคา/หมวด ต่อไอเทม) + ปุ่ม "แก้ไข" ที่บรรทัดบัญชี/ร้านค้า (แก้ vendor + payment_account_id ระดับใบเสร็จ) ในแท็บรายการรายจ่าย — ตอบโจทย์ข้อมูลกรอกผิด/OCR อ่านผิด แก้เองได้ทันทีไม่ต้องลบแล้วเพิ่มใหม่ — ทดสอบผ่าน throwaway account ทั้งสองปุ่มสำเร็จ
- [x] Autocomplete ช่อง "ร้านค้า" (`<datalist>` ดึงชื่อ vendor ที่เคยกรอกไว้ ไม่ซ้ำ สูงสุด 500 รายการล่าสุด) ใช้ร่วมกันทั้งฟอร์มเพิ่มรายจ่ายและช่องแก้ไขร้านค้าในแท็บรายการรายจ่าย
- [x] แก้บั๊ก "No option" ที่ dropdown "จ่ายจากบัญชี" (และ dropdown อื่นที่พึ่งข้อมูลจาก afterLogin) — เดิม `showApp()` เรียกก่อน query ข้อมูลอ้างอิง (categories/channels/payment_accounts/products) เสร็จ ทำให้มีช่วงเวลาสั้นๆ ที่ผู้ใช้กดโต้ตอบกับ select ที่ยังไม่มี option ได้ (severe บนมือถือ/เน็ตช้า — native picker โชว์ "No option") แก้โดยย้าย `showApp()` ไปเรียกหลัง `Promise.all` ของ query อ้างอิงทั้งหมดเสร็จแล้วเท่านั้น
- [x] แนบรูปสลิปได้หลายรูป + เลือกจากอัลบั้มได้ (ตัด `capture=environment` ออกจากช่องแนบหลักฐาน) — เพิ่มตาราง `expense_receipts`, ทดสอบผ่าน throwaway account: แนบ 2 รูปพร้อมกันสำเร็จ, บันทึกลง `expense_receipts` ถูกต้อง, แท็บรายการรายจ่ายแสดงปุ่ม "รูป 1"/"รูป 2" เปิดได้จริงทั้งคู่, mobile viewport (375px) wrap ปุ่มไม่ล้นจอ, ยืนยัน RLS บล็อก anon ทั้ง select/insert (ระวัง: การทดสอบ anon ด้วย `createClient()` ตัวที่สองในหน้าเดิมจะ**หลอกผ่าน**เพราะ localStorage session ของ client ที่ login ไว้แล้วถูกแชร์ข้ามกัน ต้องทดสอบด้วย raw `fetch` ที่ใส่แค่ publishable key เท่านั้นถึงจะแม่นยำ)
- [x] เอกสาร architecture ถาวร (`CLAUDE.md`/`PROJECT_OVERVIEW.md`) — อัปเดตต่อเนื่องทุก phase

## Phase ถัดไป (ยังไม่เริ่ม)
- คำนวณต้นทุนต่อเมนู (recipe costing) — ต้องผูกกับ `menu_items` ของ CRM repo (`buddy-platform`), Phase 4 เตรียม "ราคาต่อหน่วยใช้งาน" ไว้ให้พร้อมแล้วแต่ยังไม่มีหน้าคำนวณสูตรอาหาร (เจ้าของร้านพักเรื่องนี้ไว้ก่อนตั้งแต่ Phase 5 เพื่อโฟกัสรายรับ-รายจ่ายให้ตรงบัญชีจริงก่อน — ยังไม่ได้ยกเลิก แค่ยังไม่กลับมาทำ)
- เชื่อมค่าเสื่อมจริงจาก asset registry เข้ากับ cost model comparison (ตอนนี้ยังใช้ตัวเลข fixed model คงที่ ไม่ได้ผูกกับ `assets` จริง)
- ตาราง staff/role แยกสิทธิ์
- แจ้งเตือนอัตโนมัติเมื่อครบกำหนดผ่อน
- ปุ่ม "แก้ไข" รายการรายจ่ายเดิม (ตอนนี้มีแค่เพิ่ม/ลบ ยังไม่มีแก้ไข — เจ้าของร้านเลือก scope นี้ไว้ก่อนตอนสร้างแท็บ "รายการรายจ่าย")
- รองรับไฟล์ POS แบบ **line-item level** (ไม่ใช่แค่สรุปตามประเภทการชำระเงิน) — เจ้าของร้านเตือนไว้ว่าเดือนถัดๆ ไปอาจได้ไฟล์ export คนละรูปแบบจาก POS เดียวกัน ต้องดูไฟล์จริงตอนเจอก่อนค่อยออกแบบ mapping ใหม่ (ระบบ column-mapping ปัจจุบันน่าจะรองรับได้บางส่วนอยู่แล้วเพราะไม่ hardcode ตาม format)

---

## 11. ปัญหาที่เจอระหว่างทาง (กันแก้ซ้ำ)

1. **ชื่อ server ใน `.claude/launch.json` ชนกับของ CRM repo** — harness อ่าน launch.json จาก root `K:\My Drive\Buddy Brew\.claude\launch.json` (ไฟล์เดียวใช้ร่วมกันทั้งโฟลเดอร์ ไม่ใช่ต่อ repo) ถ้าตั้งชื่อ server ซ้ำกับที่มีอยู่แล้ว (เช่น `docs-static`) จะได้ server ผิดตัว (เจอ CRM's index.html แทน accounting.html) — ต้องตั้งชื่อ server ให้ไม่ซ้ำกันเสมอ (`accounting-docs-static`)
2. **แท็บ recon/report/assets ค้างข้อมูลเก่า** ถ้าไม่ reload ตอนเปิดแท็บ — ตอนแรกพึ่งให้ save handler อื่น (เช่น save-expense) เรียก `loadReport()` ให้เฉยๆ ทำให้ถ้า user เพิ่มรายรับอย่างเดียวไม่เคยเพิ่มรายจ่ายเลย แท็บรายงานจะไม่อัปเดต — แก้โดยให้ tab-click handler เรียก load ใหม่ทุกครั้งที่เปิดแท็บนั้นเสมอ ไม่พึ่ง save handler อื่น
3. **RLS เหมือนที่ CRM เจอ**: grant ตารางอย่างเดียวไม่พอ ต้องมี `create policy` จริงด้วยเสมอ (grant = มีสิทธิ์แตะตารางไหม, policy = เห็น/แก้แถวไหนได้บ้าง)
4. **Supabase CLI ไม่ต้องใช้ Node.js** — ติดตั้งแบบ standalone binary จาก GitHub releases (`supabase_windows_amd64.zip`) ได้เลย ไม่ต้องพึ่ง npm
5. **`supabase db push` ใช้กับ repo นี้ไม่ได้ตรงๆ** เพราะ migration history table ในฐานข้อมูลมีรายการของ CRM repo ปนอยู่ (ใช้ Supabase project เดียวกัน) CLI จะ error ว่าหา local migration file ไม่เจอ — ใช้ `supabase db query --linked -f <file>` แทน (รัน SQL ตรงๆ ผ่าน Management API ไม่ยุ่งกับ migration history tracking เลย)
6. **`db query --linked --reveal` ของ legacy JWT key (anon/service_role แบบเก่า) โชว์เต็มโดยไม่ต้องขอ reveal พิเศษ** ต่างจาก key รูปแบบใหม่ (`sb_secret_...`) ที่ mask ให้อัตโนมัติ — ระวังเวลา debug อย่า echo output ที่มี legacy key ออกมาเต็มๆ ในที่ที่เก็บ log ไว้นาน
7. **Invoke-RestMethod ของ PowerShell โดน Supabase บล็อกตอนใช้ secret key** ("Forbidden use of secret API key in browser") เพราะ Supabase ตรวจ User-Agent แล้วคิดว่าเป็น browser — แก้ด้วยการใส่ `-UserAgent "some-non-browser-string"` ตอนเรียก
8. **SheetJS (`XLSX.read`) auto-detect วันที่ใน CSV แล้วตีความผิด** — ข้อความ "01/07/2569" (ตั้งใจให้เป็น DD/MM/YYYY พ.ศ.) ถูก SheetJS เดาเป็นวันที่เองแล้วแปลงเป็น Date/serial โดยไม่สนใจ format ที่ user เลือกและไม่แปลง พ.ศ.→ค.ศ. ให้ (ได้ปี "2569" ทื่อๆ ปนกับเดือน/วันที่สลับกัน) เกิดเฉพาะไฟล์ CSV (ไฟล์ Excel จริงที่มี cell type ชัดเจนไม่มีปัญหานี้) — แก้โดยแยก parser: **CSV ใช้ PapaParse** (ได้ raw string เสมอ ไม่ auto-type) แล้วพาร์สวันที่เองตาม format ที่เลือก, **Excel (.xlsx/.xls) ใช้ SheetJS ตามเดิม** (เชื่อ cell type จริงได้เพราะไม่ใช่การเดาจากข้อความ)
9. **ทดสอบ RLS ด้วย `supabase.createClient()` ตัวที่สองในหน้าเดิมอาจให้ผลลวง** — ถ้า client ตัวแรกในหน้า login ไว้แล้ว การสร้าง client ใหม่ (แม้จะตั้งใจส่ง anon/publishable key) จะ**แชร์ session เดิมผ่าน localStorage โดยอัตโนมัติ** (คีย์ localStorage ผูกกับ project URL ไม่ใช่ client instance) ทำให้ทดสอบ "anon เข้าไม่ได้" แล้วเห็นว่าเข้าได้ทั้งที่จริงๆ ไม่ใช่ — วิธีทดสอบที่แม่นยำคือยิง raw `fetch()` ตรงไปที่ REST endpoint ใส่แค่ header `apikey`/`Authorization: Bearer <publishable key>` เท่านั้น ไม่ผ่าน supabase-js client เลย
10. **`</div>` ปิด `#tab-income` เร็วเกินไป ทำให้การ์ด "นำเข้าจาก Bank Statement"/"นำเข้ายอดขายจาก POS" หลุดออกไปอยู่นอกทุก `.tab-panel`** — เกิดตอนแทรกการ์ดสองใบนี้ระหว่าง Phase 5/5b แล้ววาง `</div>` ปิด tab-income ไว้ก่อนการ์ดโดยไม่ได้ตั้งใจ ผลคือการ์ดทั้งสองใบ**โชว์ค้างอยู่ทุกแท็บตลอดเวลา** (ไม่ถูกซ่อนด้วย tab-switch logic เลย) ซึ่งพอมันมีบรรทัดหัวการ์ดแบบ `display:flex; justify-content:space-between` ที่ไม่มี `flex-wrap` จึงดันความกว้างทั้งหน้าล้นขวาบนจอแคบ (เห็นเป็นอาการ "เลื่อนซ้าย-ขวาได้" / เนื้อหาขอบขวาโดนตัด) — จับได้จากภาพหน้าจอจริงที่ผู้ใช้ส่งมา (เห็นแท็บ "เพิ่มรายจ่าย" active แต่การ์ด Bank Statement/POS โผล่ต่อท้ายด้วย) แก้โดยย้าย `</div>` ปิด tab-income ไปไว้หลังการ์ดทั้งสองใบจริงๆ + เพิ่ม `flex-wrap:wrap` ที่บรรทัดหัวการ์ดทั้งสองกันไม่ให้ล้นซ้ำถ้าจอแคบกว่านี้อีก — **บทเรียน**: bug ประเภทนี้ตรวจจับด้วยการวัด `scrollWidth` อัตโนมัติอย่างเดียวไม่พอ (ตอนแรกวัดผ่านหมดทุกแท็บเพราะทดสอบตอนแท็บที่มีปัญหาไม่ได้ active) ถ้าโครงสร้าง `.tab-panel` ผิดตั้งแต่ต้น (element หลุดไปอยู่นอกแท็บที่ควรอยู่) ต้องเช็ค DOM nesting ตรงๆ ด้วย ไม่ใช่แค่เช็คตัวเลขความกว้าง

---

## 12. Working conventions

- แก้โค้ด/schema → commit → push (ขอ confirm จากเจ้าของร้านก่อน push แต่ละ step ใหญ่ เพราะเป็นข้อมูลการเงินจริง — ต่างจาก CRM ที่ push ทันทีได้เลย)
- migration ใหม่ทุกตัว: ตรวจว่า enable RLS แล้วต้องมี **policy จริง** ด้วย ไม่ใช่แค่ grant
- ทดสอบผ่าน throwaway test account (สร้าง+ทดสอบ+ลบทิ้งทุกครั้ง) ไม่ใช้ credential จริงของร้านในการทดสอบอัตโนมัติ
- ก่อนจบ session: อัปเดตไฟล์นี้ (เช็คลิสต์ข้อ 10) แล้ว push
