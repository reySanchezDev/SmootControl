ALTER TABLE public.expense_categories
  ADD COLUMN IF NOT EXISTS parent_id uuid REFERENCES public.expense_categories(id);

CREATE TABLE IF NOT EXISTS public.exchange_rates (
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  currency_code text NOT NULL,
  business_date date NOT NULL,
  rate numeric(15, 4) NOT NULL CHECK (rate > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (restaurant_id, currency_code, business_date)
);

ALTER TABLE public.exchange_rates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS payment_methods_same_restaurant_or_global
  ON public.payment_methods;
CREATE POLICY payment_methods_same_restaurant_or_global
  ON public.payment_methods
  FOR ALL TO authenticated
  USING (restaurant_id IS NULL OR public.is_same_restaurant(restaurant_id))
  WITH CHECK (
    restaurant_id IS NULL OR public.is_same_restaurant(restaurant_id)
  );

DROP POLICY IF EXISTS expense_categories_same_restaurant_or_global
  ON public.expense_categories;
CREATE POLICY expense_categories_same_restaurant_or_global
  ON public.expense_categories
  FOR ALL TO authenticated
  USING (restaurant_id IS NULL OR public.is_same_restaurant(restaurant_id))
  WITH CHECK (
    restaurant_id IS NULL OR public.is_same_restaurant(restaurant_id)
  );

CREATE POLICY exchange_rates_same_restaurant
  ON public.exchange_rates
  FOR ALL TO authenticated
  USING (public.is_same_restaurant(restaurant_id))
  WITH CHECK (public.is_same_restaurant(restaurant_id));

GRANT SELECT, INSERT, UPDATE, DELETE ON public.exchange_rates TO authenticated;
