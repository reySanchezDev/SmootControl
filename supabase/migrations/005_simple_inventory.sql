ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS tracks_inventory boolean NOT NULL DEFAULT false;

INSERT INTO public.permissions (code, name)
VALUES ('inventario.gestionar', 'Gestionar inventario')
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT role.id, permission.id
FROM public.roles role
JOIN public.permissions permission
  ON permission.code = 'inventario.gestionar'
WHERE role.code = 'admin'
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS public.inventory_stock (
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  quantity_on_hand integer NOT NULL DEFAULT 0 CHECK (quantity_on_hand >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (restaurant_id, product_id)
);

CREATE TABLE IF NOT EXISTS public.inventory_movements (
  id text PRIMARY KEY,
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id),
  movement_type text NOT NULL CHECK (movement_type IN ('purchase', 'sale', 'sale_void')),
  quantity_delta integer NOT NULL CHECK (quantity_delta <> 0),
  reference_type text,
  reference_id text,
  user_id text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.inventory_stock ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_movements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS inventory_stock_same_restaurant ON public.inventory_stock;
CREATE POLICY inventory_stock_same_restaurant
  ON public.inventory_stock
  FOR ALL TO authenticated
  USING (public.is_same_restaurant(restaurant_id))
  WITH CHECK (public.is_same_restaurant(restaurant_id));

DROP POLICY IF EXISTS inventory_movements_same_restaurant ON public.inventory_movements;
CREATE POLICY inventory_movements_same_restaurant
  ON public.inventory_movements
  FOR ALL TO authenticated
  USING (public.is_same_restaurant(restaurant_id))
  WITH CHECK (public.is_same_restaurant(restaurant_id));

CREATE OR REPLACE FUNCTION public.apply_inventory_movement(
  p_id text,
  p_restaurant_id uuid,
  p_product_id uuid,
  p_movement_type text,
  p_quantity_delta integer,
  p_reference_type text DEFAULT NULL,
  p_reference_id text DEFAULT NULL,
  p_user_id text DEFAULT NULL,
  p_notes text DEFAULT NULL,
  p_created_at timestamptz DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_quantity integer;
  next_quantity integer;
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.inventory_movements
    WHERE id = p_id
  ) THEN
    RETURN;
  END IF;

  INSERT INTO public.inventory_stock (
    restaurant_id,
    product_id,
    quantity_on_hand,
    created_at,
    updated_at
  )
  VALUES (
    p_restaurant_id,
    p_product_id,
    0,
    now(),
    now()
  )
  ON CONFLICT (restaurant_id, product_id) DO NOTHING;

  SELECT quantity_on_hand
    INTO current_quantity
    FROM public.inventory_stock
    WHERE restaurant_id = p_restaurant_id
      AND product_id = p_product_id
    FOR UPDATE;

  next_quantity := current_quantity + p_quantity_delta;
  IF next_quantity < 0 THEN
    RAISE EXCEPTION 'Stock insuficiente para producto %', p_product_id
      USING ERRCODE = '23514';
  END IF;

  INSERT INTO public.inventory_movements (
    id,
    restaurant_id,
    product_id,
    movement_type,
    quantity_delta,
    reference_type,
    reference_id,
    user_id,
    notes,
    created_at
  )
  VALUES (
    p_id,
    p_restaurant_id,
    p_product_id,
    p_movement_type,
    p_quantity_delta,
    p_reference_type,
    p_reference_id,
    p_user_id,
    p_notes,
    COALESCE(p_created_at, now())
  );

  UPDATE public.inventory_stock
     SET quantity_on_hand = next_quantity,
         updated_at = now()
   WHERE restaurant_id = p_restaurant_id
     AND product_id = p_product_id;
END;
$$;
