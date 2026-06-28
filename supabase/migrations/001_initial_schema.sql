CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.restaurants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  commercial_name text NOT NULL,
  legal_name text,
  tax_identifier text,
  address text,
  phone text,
  email text,
  logo_url text,
  show_company_data_on_pdf boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid REFERENCES public.restaurants(id),
  code text NOT NULL,
  name text NOT NULL,
  description text,
  is_system boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (restaurant_id, code)
);

CREATE UNIQUE INDEX IF NOT EXISTS roles_global_code_idx
  ON public.roles (code)
  WHERE restaurant_id IS NULL;

CREATE TABLE IF NOT EXISTS public.permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.role_permissions (
  role_id uuid NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
  permission_id uuid NOT NULL REFERENCES public.permissions(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  restaurant_id uuid REFERENCES public.restaurants(id),
  role_id uuid REFERENCES public.roles(id),
  display_name text NOT NULL,
  email text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.restaurant_tables (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  name text NOT NULL,
  display_name text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (restaurant_id, name)
);

CREATE TABLE IF NOT EXISTS public.product_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  parent_id uuid REFERENCES public.product_categories(id),
  name text NOT NULL,
  display_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (restaurant_id, parent_id, name)
);

CREATE TABLE IF NOT EXISTS public.products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  category_id uuid NOT NULL REFERENCES public.product_categories(id),
  code text NOT NULL,
  name text NOT NULL,
  cost numeric(15, 4) NOT NULL CHECK (cost >= 0),
  price numeric(15, 4) NOT NULL CHECK (price > 0),
  send_to_kitchen boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  is_available_in_pos boolean NOT NULL DEFAULT true,
  option_groups jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (restaurant_id, code)
);

CREATE TABLE IF NOT EXISTS public.modifier_groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  name text NOT NULL,
  is_required boolean NOT NULL DEFAULT true,
  display_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (restaurant_id, name)
);

CREATE TABLE IF NOT EXISTS public.modifier_options (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  group_id uuid NOT NULL REFERENCES public.modifier_groups(id) ON DELETE CASCADE,
  name text NOT NULL,
  price_delta numeric(15, 4) NOT NULL DEFAULT 0 CHECK (price_delta >= 0),
  display_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  is_available_in_pos boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (group_id, name)
);

CREATE TABLE IF NOT EXISTS public.product_modifier_groups (
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  modifier_group_id uuid NOT NULL REFERENCES public.modifier_groups(id),
  display_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (product_id, modifier_group_id)
);

CREATE TABLE IF NOT EXISTS public.payment_methods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid REFERENCES public.restaurants(id) ON DELETE CASCADE,
  parent_id uuid REFERENCES public.payment_methods(id),
  code text NOT NULL,
  name text NOT NULL,
  group_name text NOT NULL DEFAULT 'Otros',
  currency_code text,
  requires_reference boolean NOT NULL DEFAULT false,
  affects_cash boolean NOT NULL DEFAULT false,
  display_order integer NOT NULL DEFAULT 0,
  is_payment_target boolean NOT NULL DEFAULT true,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (restaurant_id, code)
);

CREATE UNIQUE INDEX IF NOT EXISTS payment_methods_global_code_idx
  ON public.payment_methods (code)
  WHERE restaurant_id IS NULL;

CREATE TABLE IF NOT EXISTS public.invoice_number_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL UNIQUE REFERENCES public.restaurants(id) ON DELETE CASCADE,
  prefix text,
  initial_number bigint NOT NULL DEFAULT 1,
  next_number bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (initial_number > 0),
  CHECK (next_number >= initial_number)
);

CREATE TABLE IF NOT EXISTS public.cash_register_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  cashier_user_id uuid NOT NULL REFERENCES auth.users(id),
  opened_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz,
  business_date date NOT NULL DEFAULT CURRENT_DATE,
  opening_cash_amount numeric(15, 4) NOT NULL DEFAULT 0 CHECK (opening_cash_amount >= 0),
  counted_cash_amount numeric(15, 4),
  expected_cash_amount numeric(15, 4),
  difference_amount numeric(15, 4),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
  closing_comment text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS cash_register_one_open_per_user_day_idx
  ON public.cash_register_sessions (restaurant_id, cashier_user_id, business_date)
  WHERE status = 'open';

CREATE TABLE IF NOT EXISTS public.table_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  table_id uuid NOT NULL REFERENCES public.restaurant_tables(id),
  name text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'invoiced', 'voided')),
  created_by_user_id uuid NOT NULL REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.sales (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  local_id text UNIQUE,
  remote_id uuid,
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  cash_register_session_id uuid REFERENCES public.cash_register_sessions(id),
  table_id uuid REFERENCES public.restaurant_tables(id),
  table_account_id uuid REFERENCES public.table_accounts(id),
  account_name text,
  user_id uuid NOT NULL REFERENCES auth.users(id),
  payment_method_id uuid NOT NULL REFERENCES public.payment_methods(id),
  payment_reference text,
  invoice_number text NOT NULL,
  total_amount numeric(15, 4) NOT NULL CHECK (total_amount >= 0),
  total_cost numeric(15, 4) NOT NULL CHECK (total_cost >= 0),
  gross_profit numeric(15, 4) NOT NULL,
  status text NOT NULL DEFAULT 'completed' CHECK (status IN ('completed', 'voided')),
  sync_status text NOT NULL DEFAULT 'pending' CHECK (sync_status IN ('pending', 'syncing', 'synced', 'error')),
  sold_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (restaurant_id, invoice_number)
);

CREATE TABLE IF NOT EXISTS public.sale_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sale_id uuid NOT NULL REFERENCES public.sales(id) ON DELETE CASCADE,
  product_id uuid REFERENCES public.products(id),
  table_account_id uuid REFERENCES public.table_accounts(id),
  product_code text NOT NULL,
  product_name text NOT NULL,
  category_id uuid,
  category_name text NOT NULL,
  selected_options_label text,
  quantity numeric(15, 4) NOT NULL CHECK (quantity > 0),
  unit_price numeric(15, 4) NOT NULL CHECK (unit_price >= 0),
  unit_cost numeric(15, 4) NOT NULL CHECK (unit_cost >= 0),
  subtotal numeric(15, 4) NOT NULL CHECK (subtotal >= 0),
  gross_profit numeric(15, 4) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.sale_voids (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sale_id uuid NOT NULL UNIQUE REFERENCES public.sales(id),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  cash_register_session_id uuid REFERENCES public.cash_register_sessions(id),
  voided_by_user_id uuid NOT NULL REFERENCES auth.users(id),
  reason text NOT NULL,
  original_total_amount numeric(15, 4) NOT NULL,
  original_payment_method_id uuid REFERENCES public.payment_methods(id),
  original_payment_reference text,
  sync_status text NOT NULL DEFAULT 'pending' CHECK (sync_status IN ('pending', 'syncing', 'synced', 'error')),
  voided_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.expense_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid REFERENCES public.restaurants(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  display_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (restaurant_id, name)
);

CREATE UNIQUE INDEX IF NOT EXISTS expense_categories_global_name_idx
  ON public.expense_categories (name)
  WHERE restaurant_id IS NULL;

CREATE TABLE IF NOT EXISTS public.operating_expenses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  local_id text UNIQUE,
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  expense_category_id uuid NOT NULL REFERENCES public.expense_categories(id),
  cash_register_session_id uuid REFERENCES public.cash_register_sessions(id),
  payment_method_id uuid REFERENCES public.payment_methods(id),
  created_by_user_id uuid NOT NULL REFERENCES auth.users(id),
  description text NOT NULL,
  amount numeric(15, 4) NOT NULL CHECK (amount > 0),
  comment text,
  sync_status text NOT NULL DEFAULT 'pending' CHECK (sync_status IN ('pending', 'syncing', 'synced', 'error')),
  spent_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.settings (
  restaurant_id uuid PRIMARY KEY REFERENCES public.restaurants(id) ON DELETE CASCADE,
  sync_interval_minutes integer NOT NULL DEFAULT 5 CHECK (sync_interval_minutes IN (5, 20, 30)),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.sync_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid REFERENCES public.restaurants(id) ON DELETE CASCADE,
  entity_name text NOT NULL,
  entity_local_id text,
  status text NOT NULL CHECK (status IN ('pending', 'syncing', 'synced', 'error')),
  message text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid REFERENCES public.restaurants(id) ON DELETE CASCADE,
  actor_user_id uuid REFERENCES auth.users(id),
  action text NOT NULL,
  entity_name text NOT NULL,
  entity_id uuid,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.current_restaurant_id()
RETURNS uuid
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT restaurant_id
  FROM public.profiles
  WHERE id = auth.uid()
    AND is_active = true
  LIMIT 1
$$;

CREATE OR REPLACE FUNCTION public.is_same_restaurant(target_restaurant_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT target_restaurant_id = public.current_restaurant_id()
$$;

ALTER TABLE public.restaurants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.restaurant_tables ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.modifier_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.modifier_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_modifier_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_number_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_register_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.table_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sale_voids ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.operating_expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sync_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY restaurants_same_restaurant ON public.restaurants
  FOR ALL TO authenticated USING (public.is_same_restaurant(id));

CREATE POLICY profiles_self_or_same_restaurant ON public.profiles
  FOR ALL TO authenticated USING (id = auth.uid() OR public.is_same_restaurant(restaurant_id));

CREATE POLICY roles_same_restaurant_or_global ON public.roles
  FOR SELECT TO authenticated USING (restaurant_id IS NULL OR public.is_same_restaurant(restaurant_id));

CREATE POLICY permissions_read ON public.permissions
  FOR SELECT TO authenticated USING (true);

CREATE POLICY role_permissions_read ON public.role_permissions
  FOR SELECT TO authenticated USING (true);

CREATE POLICY payment_methods_same_restaurant_or_global ON public.payment_methods
  FOR SELECT TO authenticated USING (restaurant_id IS NULL OR public.is_same_restaurant(restaurant_id));

CREATE POLICY expense_categories_same_restaurant_or_global ON public.expense_categories
  FOR SELECT TO authenticated USING (restaurant_id IS NULL OR public.is_same_restaurant(restaurant_id));

CREATE POLICY restaurant_tables_same_restaurant ON public.restaurant_tables
  FOR ALL TO authenticated USING (public.is_same_restaurant(restaurant_id));

CREATE POLICY product_categories_same_restaurant ON public.product_categories
  FOR ALL TO authenticated USING (public.is_same_restaurant(restaurant_id));

CREATE POLICY products_same_restaurant ON public.products
  FOR ALL TO authenticated USING (public.is_same_restaurant(restaurant_id));

CREATE POLICY modifier_groups_same_restaurant ON public.modifier_groups
  FOR ALL TO authenticated USING (public.is_same_restaurant(restaurant_id));

CREATE POLICY modifier_options_same_restaurant ON public.modifier_options
  FOR ALL TO authenticated USING (public.is_same_restaurant(restaurant_id));

CREATE POLICY product_modifier_groups_same_restaurant
  ON public.product_modifier_groups
  FOR ALL TO authenticated USING (public.is_same_restaurant(restaurant_id));

CREATE POLICY invoice_settings_same_restaurant ON public.invoice_number_settings
  FOR ALL TO authenticated USING (public.is_same_restaurant(restaurant_id));

CREATE POLICY cash_sessions_same_restaurant ON public.cash_register_sessions
  FOR ALL TO authenticated USING (public.is_same_restaurant(restaurant_id));

CREATE POLICY table_accounts_same_restaurant ON public.table_accounts
  FOR ALL TO authenticated USING (public.is_same_restaurant(restaurant_id));

CREATE POLICY sales_same_restaurant ON public.sales
  FOR ALL TO authenticated USING (public.is_same_restaurant(restaurant_id));

CREATE POLICY sale_items_by_sale_restaurant ON public.sale_items
  FOR ALL TO authenticated USING (
    EXISTS (
      SELECT 1 FROM public.sales s
      WHERE s.id = sale_id
        AND public.is_same_restaurant(s.restaurant_id)
    )
  );

CREATE POLICY sale_voids_same_restaurant ON public.sale_voids
  FOR ALL TO authenticated USING (public.is_same_restaurant(restaurant_id));

CREATE POLICY operating_expenses_same_restaurant ON public.operating_expenses
  FOR ALL TO authenticated USING (public.is_same_restaurant(restaurant_id));

CREATE POLICY settings_same_restaurant ON public.settings
  FOR ALL TO authenticated USING (public.is_same_restaurant(restaurant_id));

CREATE POLICY sync_logs_same_restaurant ON public.sync_logs
  FOR ALL TO authenticated USING (restaurant_id IS NULL OR public.is_same_restaurant(restaurant_id));

CREATE POLICY audit_logs_same_restaurant ON public.audit_logs
  FOR ALL TO authenticated USING (restaurant_id IS NULL OR public.is_same_restaurant(restaurant_id));

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_restaurant_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_same_restaurant(uuid) TO authenticated;
