-- Restore the documented negative-stock exception for recipe raw materials.
BEGIN;

CREATE OR REPLACE FUNCTION public.apply_inventory_movement_v2(
  p_id text, p_restaurant_id uuid, p_item_id uuid, p_product_id uuid,
  p_movement_type text, p_quantity_delta numeric,
  p_reference_type text DEFAULT NULL, p_reference_id text DEFAULT NULL,
  p_user_id text DEFAULT NULL, p_notes text DEFAULT NULL,
  p_created_at timestamptz DEFAULT NULL, p_unit_cost numeric DEFAULT 0
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  current_quantity numeric(18, 6);
  next_quantity numeric(18, 6);
  v_item_class text;
  v_allows_negative boolean := false;
BEGIN
  p_item_id := COALESCE(p_item_id, p_product_id);
  IF NOT public.is_same_restaurant(p_restaurant_id) THEN
    RAISE EXCEPTION 'No autorizado para inventario del restaurante %', p_restaurant_id
      USING ERRCODE = '42501';
  END IF;
  IF p_id IS NULL OR btrim(p_id) = '' OR p_item_id IS NULL THEN
    RAISE EXCEPTION 'Movimiento de inventario sin id o item' USING ERRCODE = '23502';
  END IF;
  IF p_movement_type NOT IN (
    'purchase', 'sale', 'sale_void', 'adjustment', 'recipe_consumption',
    'staff_raw_material_consumption'
  ) THEN
    RAISE EXCEPTION 'Tipo de movimiento de inventario invalido: %', p_movement_type
      USING ERRCODE = '23514';
  END IF;
  IF p_quantity_delta IS NULL OR p_quantity_delta = 0
     OR COALESCE(p_unit_cost, 0) < 0 THEN
    RAISE EXCEPTION 'Cantidad o costo de inventario invalido' USING ERRCODE = '23514';
  END IF;

  SELECT item_class INTO v_item_class FROM public.items
  WHERE id = p_item_id AND restaurant_id = p_restaurant_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Articulo no pertenece al restaurante' USING ERRCODE = '23503';
  END IF;
  IF p_movement_type = 'recipe_consumption'
     AND v_item_class = 'raw_material' THEN
    v_allows_negative := public.app_allows_raw_recipe_negative_stock(
      p_restaurant_id
    );
  END IF;
  IF EXISTS (SELECT 1 FROM public.inventory_movements WHERE id = p_id) THEN
    RETURN;
  END IF;

  INSERT INTO public.inventory_stock(
    restaurant_id, item_id, quantity_on_hand, created_at, updated_at
  ) VALUES (p_restaurant_id, p_item_id, 0, now(), now())
  ON CONFLICT (restaurant_id, item_id) DO NOTHING;

  SELECT quantity_on_hand INTO current_quantity
  FROM public.inventory_stock
  WHERE restaurant_id = p_restaurant_id AND item_id = p_item_id
  FOR UPDATE;
  next_quantity := COALESCE(current_quantity, 0) + p_quantity_delta;
  IF next_quantity < 0 AND NOT v_allows_negative THEN
    RAISE EXCEPTION 'Stock insuficiente' USING ERRCODE = '23514';
  END IF;

  INSERT INTO public.inventory_movements(
    id, restaurant_id, item_id, movement_type, quantity_delta,
    reference_type, reference_id, user_id, notes, created_at, unit_cost
  ) VALUES (
    p_id, p_restaurant_id, p_item_id, p_movement_type, p_quantity_delta,
    p_reference_type, p_reference_id, p_user_id, p_notes,
    COALESCE(p_created_at, now()), COALESCE(p_unit_cost, 0)
  );
  UPDATE public.inventory_stock
  SET quantity_on_hand = next_quantity, updated_at = now()
  WHERE restaurant_id = p_restaurant_id AND item_id = p_item_id;
END;
$$;

-- This is an internal movement primitive. Client writes must go through the
-- permission-checked purchase, adjustment, sale, recipe, or staff RPCs.
REVOKE ALL ON FUNCTION public.apply_inventory_movement_v2(
  text, uuid, uuid, uuid, text, numeric, text, text, text, text, timestamptz, numeric
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.apply_inventory_movement_v2(
  text, uuid, uuid, uuid, text, numeric, text, text, text, text, timestamptz, numeric
) TO service_role;
REVOKE ALL ON FUNCTION public.pos_apply_recipe_inventory_movements(
  uuid, uuid, text
) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pos_reverse_recipe_inventory_movements(
  uuid, uuid
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.pos_apply_recipe_inventory_movements(
  uuid, uuid, text
) TO service_role;
GRANT EXECUTE ON FUNCTION public.pos_reverse_recipe_inventory_movements(
  uuid, uuid
) TO service_role;

COMMIT;
