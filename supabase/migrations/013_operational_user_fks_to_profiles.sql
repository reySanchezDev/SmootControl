-- POS users are operational profiles, not necessarily Supabase Auth users.
-- Cash register, sales, expenses and audit records must therefore reference
-- public.profiles so offline/PIN users can sync operational data.

ALTER TABLE public.cash_register_sessions
  DROP CONSTRAINT IF EXISTS cash_register_sessions_cashier_user_id_fkey;

ALTER TABLE public.cash_register_sessions
  ADD CONSTRAINT cash_register_sessions_cashier_user_id_fkey
  FOREIGN KEY (cashier_user_id)
  REFERENCES public.profiles(id);

ALTER TABLE public.table_accounts
  DROP CONSTRAINT IF EXISTS table_accounts_created_by_user_id_fkey;

ALTER TABLE public.table_accounts
  ADD CONSTRAINT table_accounts_created_by_user_id_fkey
  FOREIGN KEY (created_by_user_id)
  REFERENCES public.profiles(id);

ALTER TABLE public.sales
  DROP CONSTRAINT IF EXISTS sales_user_id_fkey;

ALTER TABLE public.sales
  ADD CONSTRAINT sales_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES public.profiles(id);

ALTER TABLE public.sale_voids
  DROP CONSTRAINT IF EXISTS sale_voids_voided_by_user_id_fkey;

ALTER TABLE public.sale_voids
  ADD CONSTRAINT sale_voids_voided_by_user_id_fkey
  FOREIGN KEY (voided_by_user_id)
  REFERENCES public.profiles(id);

ALTER TABLE public.operating_expenses
  DROP CONSTRAINT IF EXISTS operating_expenses_created_by_user_id_fkey;

ALTER TABLE public.operating_expenses
  ADD CONSTRAINT operating_expenses_created_by_user_id_fkey
  FOREIGN KEY (created_by_user_id)
  REFERENCES public.profiles(id);

ALTER TABLE public.audit_logs
  DROP CONSTRAINT IF EXISTS audit_logs_actor_user_id_fkey;

ALTER TABLE public.audit_logs
  ADD CONSTRAINT audit_logs_actor_user_id_fkey
  FOREIGN KEY (actor_user_id)
  REFERENCES public.profiles(id);

COMMENT ON CONSTRAINT cash_register_sessions_cashier_user_id_fkey
  ON public.cash_register_sessions IS
  'References operational POS/admin profiles, not auth.users.';

COMMENT ON CONSTRAINT sales_user_id_fkey
  ON public.sales IS
  'References operational POS/admin profiles, not auth.users.';

NOTIFY pgrst, 'reload schema';
