-- เลขที่รายจ่าย (running number) ต่อใบเสร็จ 1 ใบ ใช้อ้างอิงระหว่าง slip / ออเดอร์ Shopee / รายการในระบบ
-- backfill เรียงตาม expense_date, created_at (แถวเก่าได้เลขตามลำดับวันที่) แถวใหม่ได้เลขต่อจากนั้นตามลำดับที่สร้าง
alter table expenses add column if not exists expense_no bigint;
create sequence if not exists expenses_expense_no_seq owned by expenses.expense_no;
with o as (select id, row_number() over (order by expense_date, created_at, id) n from expenses where expense_no is null)
update expenses e set expense_no = o.n from o where o.id = e.id;
select setval('expenses_expense_no_seq', (select coalesce(max(expense_no), 0) from expenses) + 1, false);
alter table expenses alter column expense_no set default nextval('expenses_expense_no_seq');
alter table expenses alter column expense_no set not null;
create unique index if not exists expenses_expense_no_key on expenses (expense_no);
