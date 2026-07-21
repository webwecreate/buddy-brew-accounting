-- สินค้า (products) — รายชื่อสินค้ากลาง + หน่วยแปลง เพื่อ (1) แก้ปัญหาชื่อไม่ตรงกัน (OCR/พิมพ์เองอาจได้คนละชื่อ)
-- โดยให้ expense_items ผูกกับสินค้าตัวเดียวกันได้ (2) เก็บอัตราแปลงหน่วยซื้อ→หน่วยใช้งานจริง (เช่น 1 แพ็ค = 6 ขวด)
-- เพื่อคำนวณราคาต่อหน่วยใช้งานสำหรับต้นทุนต่อเมนูในอนาคต โดยไม่ต้องเปลี่ยนวิธีบันทึกรายจ่าย (ยังบันทึกตามหน่วยซื้อจริงเหมือนเดิม)

create table products (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,             -- ชื่อทางการ กันสร้างซ้ำโดยไม่ตั้งใจ
  category_id uuid references expense_categories(id),
  purchase_unit_label text not null,     -- เช่น 'แพ็ค (6 ขวด)', 'ถุง 1kg'
  usage_unit_label text not null,        -- เช่น 'ขวด', 'กรัม', 'มล.' — เลือกตามการใช้งานจริงต่อสินค้า
  conversion_qty numeric not null check (conversion_qty > 0),  -- 1 หน่วยซื้อ = กี่หน่วยใช้งาน
  note text,
  active boolean not null default true,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

-- ผูก expense_items เข้ากับสินค้าได้ (ไม่บังคับ) — quantity/unit_price ของ expense_items ยังหมายถึงหน่วยซื้อเหมือนเดิมทุกอย่าง
-- ราคาต่อหน่วยใช้งาน = unit_price ÷ conversion_qty คำนวณตอนแสดงผลเท่านั้น ไม่เก็บเป็นคอลัมน์
alter table expense_items add column product_id uuid references products(id) on delete set null;

alter table products enable row level security;
grant select, insert, update, delete on table products to authenticated;
create policy "products authenticated full access" on products
  for all to authenticated using (true) with check (true);

notify pgrst, 'reload schema';
