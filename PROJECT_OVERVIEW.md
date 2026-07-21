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
│       └── 20260721010000_expense_payment_accounts.sql   ← payment_accounts, expenses.payment_account_id (แทน payment_method เดิม)
└── .github/workflows/deploy-functions.yml  ← auto-deploy edge functions
```

---

## 7. Database schema

### `expense_categories` — หมวดรายจ่าย (seed จาก `Accounting/fixed_cost_v1.md`)
`key, label_th, group_key (depreciation/overhead/labor/variable/other), fixed_cost_model_monthly (null = ไม่มีในโมเดล), sort_order, active`

### `income_channels` — ช่องทางรายรับ (seed: grab, in_store, government)
`key, label_th, note, sort_order, active`

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

---

## 8. RLS model

ทุกตารางในระบบนี้ (ไม่มีข้อยกเว้น): เปิด RLS + policy `for all to authenticated using (true) with check (true)` — โมเดล "login แล้วผ่าน Supabase Auth = staff ที่เชื่อถือได้" ยังไม่มีตาราง role แยก (ถ้ามี staff/role table ในอนาคตค่อยจำกัดสิทธิ์ละเอียดขึ้น)

**ต่างจาก CRM repo ตรงนี้**: CRM มี `menu_items`/`bean_options` ที่เปิดให้ `anon` อ่านได้ (เพราะ Staff Panel ยังไม่มี login ตอนนั้น) — **ระบบนี้ไม่มีข้อยกเว้นแบบนั้นเลย ไม่มี anon access ที่ตารางไหนทั้งสิ้น** เพราะเป็นข้อมูลการเงินล้วนๆ (ทดสอบยืนยันแล้วว่า anon key เจอ "permission denied" ทุกตาราง)

Storage bucket `receipts` (private) ก็ใช้โมเดลเดียวกัน — policy จำกัดที่ `authenticated` เท่านั้น

---

## 9. แท็บ / UI breakdown (`docs/accounting.html`)

หน้าเดียว ไม่มี router, toggle ด้วย `.tabbar button[data-tab]` + `#tab-<name>` — ทุกแท็บที่โชว์ข้อมูลรวม (recon/report/assets) reload ข้อมูลใหม่ตอนเปิดแท็บเสมอ (ดูข้อ 11 บั๊กที่เจอ)

1. **เพิ่มรายจ่าย** — ถ่ายรูปใบเสร็จ → OCR (`receipt-ocr` function) prefill รายการสินค้าเป็นแถวๆ (ชื่อ/จำนวน/ราคา/หมวด) → แก้ไขได้ทุกช่องก่อนบันทึกเสมอ → เลือก "จ่ายจากบัญชี" (SCB/KTB/กรุงศรี/เงินสด/เงินส่วนตัวเจ้าของ) → insert `expenses` + `expense_items` + อัปโหลดรูปเข้า bucket `receipts`
2. **รายการรายจ่าย** — ledger/บัญชีแยกประเภท (ต่างจาก "รายงานเดือน" ที่เป็นสรุปภาพใหญ่): browse รายการรายจ่ายแบบรายไอเทม กรองตามช่วงวันที่/หมวดหมู่/บัญชีที่จ่าย, จัดกลุ่มตามวันที่, ลบรายการได้ (ลบ item สุดท้ายของใบเสร็จแล้ว auto ลบ header ที่ว่างเปล่าทิ้งด้วย) — ยังไม่มีปุ่มแก้ไข (เป็น scope รอบถัดไปถ้าต้องการ)
3. **เพิ่มรายรับ** — เลือกช่องทาง + ประเภทยอด (ตามระบบ/โอนเข้าจริง) → insert `income_entries`
4. **กระทบยอด** — เลือกเดือน → เทียบยอดตามระบบ vs โอนเข้าจริง แยก 3 ช่องทาง
5. **รายงานเดือน** — สรุปรายจ่ายจริงตามหมวดเทียบ cost model, รายจ่ายแยกตามบัญชีที่จ่าย, รายรับ-รายจ่ายรวม, มูลค่าทรัพย์สินสุทธิ, หนี้สินคงค้างแยกตามเจ้าหนี้
6. **ทรัพย์สิน/หนี้** — 2 การ์ด: (a) เพิ่ม/ดูทรัพย์สิน พร้อมค่าเสื่อมสะสม+มูลค่าคงเหลือคำนวณสด (b) เพิ่ม/ดูหนี้สิน พร้อมบันทึกจ่ายเป็นงวดๆ ต่อรายการ

---

## 10. สถานะปัจจุบัน

- [x] Phase 1: schema รายรับ-รายจ่าย + storage bucket + OCR function + 4 แท็บแรก — build จริง, deploy จริง, ทดสอบ end-to-end จริงกับ Supabase (login, RLS, OCR round-trip, บันทึกจริง) ผ่านหมดแล้ว
- [x] Phase 2: schema assets/liabilities + trigger — apply จริงแล้ว ทดสอบ trigger จริง (partial payment, full payoff, reverse on delete) ผ่านหมด
- [x] แท็บ "ทรัพย์สิน/หนี้" + อัปเดตแท็บรายงานเดือน — เขียนโค้ดเสร็จ ทดสอบจริง (scenario เครื่องชงกาแฟ 50,000 เป็นหนี้เจ้าของ ค่อยๆ จ่ายจนหมด) ผ่านหมด
- [x] Phase 3: `payment_accounts` (SCB/KTB/กรุงศรี/เงินสด/เงินส่วนตัวเจ้าของ) + `expenses.payment_account_id` แทน `payment_method` เดิม + รายงานแยกตามบัญชี — apply จริง ทดสอบจริงผ่านหมด
- [x] เอกสาร architecture ถาวร (`CLAUDE.md`/`PROJECT_OVERVIEW.md`) — สร้างแล้ว (ไฟล์นี้)
- [ ] เปิด GitHub Pages ใน repo settings — **รอเจ้าของร้านทำเอง** (ทำผ่าน CLI/API ไม่ได้)
- [ ] ทดสอบ Phase 2 บน UI จริงผ่าน throwaway test account + ลบข้อมูลทดสอบทิ้ง
- [ ] Commit + push Phase 2

## Phase ถัดไป (ยังไม่เริ่ม)
- เชื่อมค่าเสื่อมจริงจาก asset registry เข้ากับ cost model comparison (ตอนนี้ยังใช้ตัวเลข fixed model คงที่ ไม่ได้ผูกกับ `assets` จริง)
- ตาราง staff/role แยกสิทธิ์
- แจ้งเตือนอัตโนมัติเมื่อครบกำหนดผ่อน

---

## 11. ปัญหาที่เจอระหว่างทาง (กันแก้ซ้ำ)

1. **ชื่อ server ใน `.claude/launch.json` ชนกับของ CRM repo** — harness อ่าน launch.json จาก root `K:\My Drive\Buddy Brew\.claude\launch.json` (ไฟล์เดียวใช้ร่วมกันทั้งโฟลเดอร์ ไม่ใช่ต่อ repo) ถ้าตั้งชื่อ server ซ้ำกับที่มีอยู่แล้ว (เช่น `docs-static`) จะได้ server ผิดตัว (เจอ CRM's index.html แทน accounting.html) — ต้องตั้งชื่อ server ให้ไม่ซ้ำกันเสมอ (`accounting-docs-static`)
2. **แท็บ recon/report/assets ค้างข้อมูลเก่า** ถ้าไม่ reload ตอนเปิดแท็บ — ตอนแรกพึ่งให้ save handler อื่น (เช่น save-expense) เรียก `loadReport()` ให้เฉยๆ ทำให้ถ้า user เพิ่มรายรับอย่างเดียวไม่เคยเพิ่มรายจ่ายเลย แท็บรายงานจะไม่อัปเดต — แก้โดยให้ tab-click handler เรียก load ใหม่ทุกครั้งที่เปิดแท็บนั้นเสมอ ไม่พึ่ง save handler อื่น
3. **RLS เหมือนที่ CRM เจอ**: grant ตารางอย่างเดียวไม่พอ ต้องมี `create policy` จริงด้วยเสมอ (grant = มีสิทธิ์แตะตารางไหม, policy = เห็น/แก้แถวไหนได้บ้าง)
4. **Supabase CLI ไม่ต้องใช้ Node.js** — ติดตั้งแบบ standalone binary จาก GitHub releases (`supabase_windows_amd64.zip`) ได้เลย ไม่ต้องพึ่ง npm
5. **`supabase db push` ใช้กับ repo นี้ไม่ได้ตรงๆ** เพราะ migration history table ในฐานข้อมูลมีรายการของ CRM repo ปนอยู่ (ใช้ Supabase project เดียวกัน) CLI จะ error ว่าหา local migration file ไม่เจอ — ใช้ `supabase db query --linked -f <file>` แทน (รัน SQL ตรงๆ ผ่าน Management API ไม่ยุ่งกับ migration history tracking เลย)
6. **`db query --linked --reveal` ของ legacy JWT key (anon/service_role แบบเก่า) โชว์เต็มโดยไม่ต้องขอ reveal พิเศษ** ต่างจาก key รูปแบบใหม่ (`sb_secret_...`) ที่ mask ให้อัตโนมัติ — ระวังเวลา debug อย่า echo output ที่มี legacy key ออกมาเต็มๆ ในที่ที่เก็บ log ไว้นาน
7. **Invoke-RestMethod ของ PowerShell โดน Supabase บล็อกตอนใช้ secret key** ("Forbidden use of secret API key in browser") เพราะ Supabase ตรวจ User-Agent แล้วคิดว่าเป็น browser — แก้ด้วยการใส่ `-UserAgent "some-non-browser-string"` ตอนเรียก

---

## 12. Working conventions

- แก้โค้ด/schema → commit → push (ขอ confirm จากเจ้าของร้านก่อน push แต่ละ step ใหญ่ เพราะเป็นข้อมูลการเงินจริง — ต่างจาก CRM ที่ push ทันทีได้เลย)
- migration ใหม่ทุกตัว: ตรวจว่า enable RLS แล้วต้องมี **policy จริง** ด้วย ไม่ใช่แค่ grant
- ทดสอบผ่าน throwaway test account (สร้าง+ทดสอบ+ลบทิ้งทุกครั้ง) ไม่ใช้ credential จริงของร้านในการทดสอบอัตโนมัติ
- ก่อนจบ session: อัปเดตไฟล์นี้ (เช็คลิสต์ข้อ 10) แล้ว push
