-- Reintegrates recipe raw-material consumption when a synced sale is voided.

CREATE OR REPLACE FUNCTION public.pos_reverse_recipe_inventory_movements(
  p_restaurant_id uuid,
  p_sale_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  original_movement record;
  current_quantity integer;
  next_quantity integer;
  inserted_count integer := 0;
BEGIN
  FOR original_movement IN
    SELECT
      movement.id,
      movement.product_id,
      movement.quantity_delta,
      movement.user_id
    FROM public.inventory_movements movement
    WHERE movement.restaurant_id = p_restaurant_id
      AND movement.reference_id = p_sale_id::text
      AND movement.movement_type = 'recipe_consumption'
  LOOP
    IF EXISTS (
      SELECT 1
        FROM public.inventory_movements
       WHERE id = 'recipe_void:' || original_movement.id
    ) THEN
      CONTINUE;
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
      original_movement.product_id,
      0,
      now(),
      now()
    )
    ON CONFLICT (restaurant_id, product_id) DO NOTHING;

    SELECT quantity_on_hand
      INTO current_quantity
      FROM public.inventory_stock
     WHERE restaurant_id = p_restaurant_id
       AND product_id = original_movement.product_id
     FOR UPDATE;

    next_quantity := current_quantity - original_movement.quantity_delta;

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
      'recipe_void:' || original_movement.id,
      p_restaurant_id,
      original_movement.product_id,
      'sale_void',
      -original_movement.quantity_delta,
      'sale_void',
      p_sale_id::text,
      original_movement.user_id,
      'Reintegro automatico por anulacion de receta',
      now()
    );

    UPDATE public.inventory_stock
       SET quantity_on_hand = next_quantity,
           updated_at = now()
     WHERE restaurant_id = p_restaurant_id
       AND product_id = original_movement.product_id;

    inserted_count := inserted_count + 1;
  END LOOP;

  RETURN jsonb_build_object('inserted_movements', inserted_count);
END;
$$;

ALTER FUNCTION public.pos_sync_sale(uuid, uuid, text, jsonb)
RENAME TO pos_sync_sale_recipe_void_base_20260716;

CREATE OR REPLACE FUNCTION public.pos_sync_sale(
  p_restaurant_id uuid,
  p_device_id uuid,
  p_device_secret text,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result jsonb;
  synced_sale_id uuid;
  sale_payload jsonb := COALESCE(p_payload -> 'sale', '{}'::jsonb);
  void_payload jsonb := COALESCE(p_payload -> 'void', '{}'::jsonb);
BEGIN
  result := public.pos_sync_sale_recipe_void_base_20260716(
    p_restaurant_id,
    p_device_id,
    p_device_secret,
    p_payload
  );

  synced_sale_id := NULLIF(result ->> 'remote_id', '')::uuid;
  IF synced_sale_id IS NOT NULL
     AND (
       void_payload <> '{}'::jsonb
       OR COALESCE(sale_payload ->> 'status', 'completed') = 'voided'
     ) THEN
    PERFORM public.pos_reverse_recipe_inventory_movements(
      p_restaurant_id,
      synced_sale_id
    );
  END IF;

  RETURN result;
END;
$$;

ALTER FUNCTION public.pos_sync_staff_consumption(uuid, uuid, text, jsonb)
RENAME TO pos_sync_staff_consumption_recipe_void_base_20260716;

CREATE OR REPLACE FUNCTION public.pos_sync_staff_consumption(
  p_restaurant_id uuid,
  p_device_id uuid,
  p_device_secret text,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result jsonb;
  synced_sale_id uuid;
  sale_payload jsonb := COALESCE(p_payload -> 'sale', '{}'::jsonb);
BEGIN
  result := public.pos_sync_staff_consumption_recipe_void_base_20260716(
    p_restaurant_id,
    p_device_id,
    p_device_secret,
    p_payload
  );

  synced_sale_id := NULLIF(result ->> 'remote_id', '')::uuid;
  IF synced_sale_id IS NOT NULL
     AND COALESCE(sale_payload ->> 'status', 'completed') = 'voided' THEN
    PERFORM public.pos_reverse_recipe_inventory_movements(
      p_restaurant_id,
      synced_sale_id
    );
  END IF;

  RETURN result;
END;
$$;

REVOKE ALL ON FUNCTION public.pos_reverse_recipe_inventory_movements(
  uuid,
  uuid
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pos_sync_sale(uuid, uuid, text, jsonb)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pos_sync_staff_consumption(uuid, uuid, text, jsonb)
  FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.pos_sync_sale(uuid, uuid, text, jsonb)
  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.pos_sync_staff_consumption(
  uuid,
  uuid,
  text,
  jsonb
) TO anon, authenticated, service_role;

COMMENT ON FUNCTION public.pos_reverse_recipe_inventory_movements(uuid, uuid)
  IS 'Creates idempotent positive inventory movements to reverse recipe consumption when a sale is voided.';
