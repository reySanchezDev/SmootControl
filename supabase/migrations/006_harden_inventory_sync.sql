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
  IF NOT public.is_same_restaurant(p_restaurant_id) THEN
    RAISE EXCEPTION 'No autorizado para inventario del restaurante %',
      p_restaurant_id
      USING ERRCODE = '42501';
  END IF;

  IF p_id IS NULL OR btrim(p_id) = '' THEN
    RAISE EXCEPTION 'Movimiento de inventario sin id'
      USING ERRCODE = '23502';
  END IF;

  IF p_movement_type NOT IN ('purchase', 'sale', 'sale_void') THEN
    RAISE EXCEPTION 'Tipo de movimiento de inventario invalido: %',
      p_movement_type
      USING ERRCODE = '23514';
  END IF;

  IF p_quantity_delta IS NULL OR p_quantity_delta = 0 THEN
    RAISE EXCEPTION 'Cantidad de inventario invalida'
      USING ERRCODE = '23514';
  END IF;

  IF NOT EXISTS (
    SELECT 1
      FROM public.products
     WHERE id = p_product_id
       AND restaurant_id = p_restaurant_id
  ) THEN
    RAISE EXCEPTION 'Producto de inventario no pertenece al restaurante'
      USING ERRCODE = '23503';
  END IF;

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

REVOKE ALL ON FUNCTION public.apply_inventory_movement(
  text,
  uuid,
  uuid,
  text,
  integer,
  text,
  text,
  text,
  text,
  timestamptz
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.apply_inventory_movement(
  text,
  uuid,
  uuid,
  text,
  integer,
  text,
  text,
  text,
  text,
  timestamptz
) TO authenticated;
