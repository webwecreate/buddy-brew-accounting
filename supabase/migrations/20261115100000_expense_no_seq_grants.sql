-- expense_no ใช้ default nextval('expenses_expense_no_seq') แต่ role authenticated
-- ยังไม่มีสิทธิ์ใช้ sequence ทำให้ insert รายจ่ายใหม่ล้มเหลว (permission denied for sequence)
grant usage, select on sequence expenses_expense_no_seq to authenticated;
grant usage, select on sequence expenses_expense_no_seq to service_role;
