INSERT INTO public.permissions (code, name)
VALUES
  ('tipos_venta.gestionar', 'Gestionar tipos de venta'),
  ('empaques.gestionar', 'Gestionar empaques')
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT role.id, permission.id
FROM public.roles role
JOIN public.permissions permission
  ON permission.code IN ('tipos_venta.gestionar', 'empaques.gestionar')
WHERE role.code = 'admin'
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS public.sales_types (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  code text NOT NULL,
  name text NOT NULL,
  display_order integer NOT NULL DEFAULT 0,
  is_default boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (restaurant_id, code)
);

CREATE UNIQUE INDEX IF NOT EXISTS sales_types_one_default_idx
  ON public.sales_types (restaurant_id)
  WHERE is_default;

CREATE TABLE IF NOT EXISTS public.packaging_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  name text NOT NULL,
  cost numeric(15, 4) NOT NULL DEFAULT 0 CHECK (cost >= 0),
  tracks_stock boolean NOT NULL DEFAULT true,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (restaurant_id, name)
);

CREATE TABLE IF NOT EXISTS public.product_packaging_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  sales_type_id uuid NOT NULL REFERENCES public.sales_types(id) ON DELETE CASCADE,
  packaging_item_id uuid NOT NULL REFERENCES public.packaging_items(id),
  quantity_per_unit integer NOT NULL DEFAULT 1 CHECK (quantity_per_unit > 0),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (restaurant_id, product_id, sales_type_id, packaging_item_id)
);

CREATE TABLE IF NOT EXISTS public.packaging_stock (
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  packaging_item_id uuid NOT NULL REFERENCES public.packaging_items(id) ON DELETE CASCADE,
  quantity_on_hand integer NOT NULL DEFAULT 0 CHECK (quantity_on_hand >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (restaurant_id, packaging_item_id)
);

CREATE TABLE IF NOT EXISTS public.packaging_movements (
  id text PRIMARY KEY,
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  packaging_item_id uuid NOT NULL REFERENCES public.packaging_items(id),
  movement_type text NOT NULL CHECK (
    movement_type IN (
      'packaging_purchase',
      'packaging_sale',
      'packaging_sale_void'
    )
  ),
  quantity_delta integer NOT NULL CHECK (quantity_delta <> 0),
  unit_cost numeric(15, 4) NOT NULL DEFAULT 0 CHECK (unit_cost >= 0),
  reference_type text,
  reference_id text,
  user_id text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.sales
  ADD COLUMN IF NOT EXISTS sales_type_id uuid REFERENCES public.sales_types(id),
  ADD COLUMN IF NOT EXISTS sales_type_name text;

ALTER TABLE public.sales_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.packaging_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_packaging_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.packaging_stock ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.packaging_movements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS sales_types_same_restaurant ON public.sales_types;
CREATE POLICY sales_types_same_restaurant
  ON public.sales_types
  FOR ALL TO authenticated
  USING (public.is_same_restaurant(restaurant_id))
  WITH CHECK (public.is_same_restaurant(restaurant_id));

DROP POLICY IF EXISTS packaging_items_same_restaurant ON public.packaging_items;
CREATE POLICY packaging_items_same_restaurant
  ON public.packaging_items
  FOR ALL TO authenticated
  USING (public.is_same_restaurant(restaurant_id))
  WITH CHECK (public.is_same_restaurant(restaurant_id));

DROP POLICY IF EXISTS product_packaging_rules_same_restaurant ON public.product_packaging_rules;
CREATE POLICY product_packaging_rules_same_restaurant
  ON public.product_packaging_rules
  FOR ALL TO authenticated
  USING (public.is_same_restaurant(restaurant_id))
  WITH CHECK (public.is_same_restaurant(restaurant_id));

DROP POLICY IF EXISTS packaging_stock_same_restaurant ON public.packaging_stock;
CREATE POLICY packaging_stock_same_restaurant
  ON public.packaging_stock
  FOR ALL TO authenticated
  USING (public.is_same_restaurant(restaurant_id))
  WITH CHECK (public.is_same_restaurant(restaurant_id));

DROP POLICY IF EXISTS packaging_movements_same_restaurant ON public.packaging_movements;
CREATE POLICY packaging_movements_same_restaurant
  ON public.packaging_movements
  FOR ALL TO authenticated
  USING (public.is_same_restaurant(restaurant_id))
  WITH CHECK (public.is_same_restaurant(restaurant_id));

CREATE OR REPLACE FUNCTION public.ensure_default_sales_types(p_restaurant_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_same_restaurant(p_restaurant_id) THEN
    RAISE EXCEPTION 'No autorizado para tipos de venta del restaurante %',
      p_restaurant_id
      USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.sales_types (
    restaurant_id,
    code,
    name,
    display_order,
    is_default,
    is_active
  )
  VALUES
    (
      p_restaurant_id,
      'dine_in',
      'Comer aqui',
      0,
      true,
      true
    ),
    (
      p_restaurant_id,
      'to_go',
      'Para llevar',
      1,
      false,
      true
    )
  ON CONFLICT (restaurant_id, code) DO NOTHING;
END;
$$;

CREATE OR REPLACE FUNCTION public.apply_packaging_movement(
  p_id text,
  p_restaurant_id uuid,
  p_packaging_item_id uuid,
  p_movement_type text,
  p_quantity_delta integer,
  p_unit_cost numeric DEFAULT 0,
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
  IF NOT public.is_same_restaurant(p_restaurant_id) THEN
    RAISE EXCEPTION 'No autorizado para empaques del restaurante %',
      p_restaurant_id
      USING ERRCODE = '42501';
  END IF;

  IF p_id IS NULL OR btrim(p_id) = '' THEN
    RAISE EXCEPTION 'Movimiento de empaque sin id'
      USING ERRCODE = '23502';
  END IF;

  IF p_movement_type NOT IN (
    'packaging_purchase',
    'packaging_sale',
    'packaging_sale_void'
  ) THEN
    RAISE EXCEPTION 'Tipo de movimiento de empaque invalido: %',
      p_movement_type
      USING ERRCODE = '23514';
  END IF;

  IF p_quantity_delta IS NULL OR p_quantity_delta = 0 THEN
    RAISE EXCEPTION 'Cantidad de empaque invalida'
      USING ERRCODE = '23514';
  END IF;

  IF NOT EXISTS (
    SELECT 1
      FROM public.packaging_items
     WHERE id = p_packaging_item_id
       AND restaurant_id = p_restaurant_id
  ) THEN
    RAISE EXCEPTION 'Empaque no pertenece al restaurante'
      USING ERRCODE = '23503';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.packaging_movements
    WHERE id = p_id
  ) THEN
    RETURN;
  END IF;

  INSERT INTO public.packaging_stock (
    restaurant_id,
    packaging_item_id,
    quantity_on_hand,
    created_at,
    updated_at
  )
  VALUES (
    p_restaurant_id,
    p_packaging_item_id,
    0,
    now(),
    now()
  )
  ON CONFLICT (restaurant_id, packaging_item_id) DO NOTHING;

  SELECT quantity_on_hand
    INTO current_quantity
    FROM public.packaging_stock
   WHERE restaurant_id = p_restaurant_id
     AND packaging_item_id = p_packaging_item_id
   FOR UPDATE;

  next_quantity := current_quantity + p_quantity_delta;
  IF next_quantity < 0 THEN
    RAISE EXCEPTION 'Stock insuficiente para empaque %', p_packaging_item_id
      USING ERRCODE = '23514';
  END IF;

  INSERT INTO public.packaging_movements (
    id,
    restaurant_id,
    packaging_item_id,
    movement_type,
    quantity_delta,
    unit_cost,
    reference_type,
    reference_id,
    user_id,
    notes,
    created_at
  )
  VALUES (
    p_id,
    p_restaurant_id,
    p_packaging_item_id,
    p_movement_type,
    p_quantity_delta,
    COALESCE(p_unit_cost, 0),
    p_reference_type,
    p_reference_id,
    p_user_id,
    p_notes,
    COALESCE(p_created_at, now())
  );

  UPDATE public.packaging_stock
     SET quantity_on_hand = next_quantity,
         updated_at = now()
   WHERE restaurant_id = p_restaurant_id
     AND packaging_item_id = p_packaging_item_id;
END;
$$;

REVOKE ALL ON FUNCTION public.ensure_default_sales_types(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.apply_packaging_movement(
  text,
  uuid,
  uuid,
  text,
  integer,
  numeric,
  text,
  text,
  text,
  text,
  timestamptz
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.ensure_default_sales_types(uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.apply_packaging_movement(
  text,
  uuid,
  uuid,
  text,
  integer,
  numeric,
  text,
  text,
  text,
  text,
  timestamptz
) TO authenticated;
