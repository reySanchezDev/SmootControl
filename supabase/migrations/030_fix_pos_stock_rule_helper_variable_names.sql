-- Fix helper variable names from migration 029 so PL/pgSQL does not confuse
-- local variables with table columns named sales_type_id.

CREATE OR REPLACE FUNCTION public.pos_sale_payload_for_current_stock_rules(
  p_restaurant_id uuid,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  sale_payload jsonb := COALESCE(p_payload -> 'sale', '{}'::jsonb);
  v_sales_type_id uuid :=
    NULLIF(sale_payload ->> 'sales_type_id', '')::uuid;
  inventory_payload jsonb;
  packaging_payload jsonb;
BEGIN
  SELECT COALESCE(jsonb_agg(movement.value), '[]'::jsonb)
    INTO inventory_payload
    FROM jsonb_array_elements(
      COALESCE(p_payload -> 'inventory_movements', '[]'::jsonb)
    ) AS movement(value)
    JOIN public.products product
      ON product.id = NULLIF(movement.value ->> 'product_id', '')::uuid
     AND product.restaurant_id = p_restaurant_id
   WHERE product.tracks_inventory = true;

  SELECT COALESCE(jsonb_agg(movement.value), '[]'::jsonb)
    INTO packaging_payload
    FROM jsonb_array_elements(
      COALESCE(p_payload -> 'packaging_movements', '[]'::jsonb)
    ) AS movement(value)
    JOIN public.packaging_items item
      ON item.id = NULLIF(movement.value ->> 'packaging_item_id', '')::uuid
     AND item.restaurant_id = p_restaurant_id
   WHERE item.is_active = true
     AND item.tracks_stock = true
     AND v_sales_type_id IS NOT NULL
     AND EXISTS (
       SELECT 1
         FROM jsonb_array_elements(
           COALESCE(p_payload -> 'items', '[]'::jsonb)
         ) AS sale_item(value)
         JOIN public.product_packaging_rules rule
           ON rule.product_id =
              NULLIF(sale_item.value ->> 'product_id', '')::uuid
          AND rule.restaurant_id = p_restaurant_id
        WHERE rule.sales_type_id = v_sales_type_id
          AND rule.packaging_item_id =
              NULLIF(movement.value ->> 'packaging_item_id', '')::uuid
          AND rule.is_active = true
     );

  RETURN jsonb_set(
    jsonb_set(
      p_payload,
      '{inventory_movements}',
      inventory_payload,
      true
    ),
    '{packaging_movements}',
    packaging_payload,
    true
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.pos_record_nontracked_packaging_movements(
  p_restaurant_id uuid,
  p_payload jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  sale_payload jsonb := COALESCE(p_payload -> 'sale', '{}'::jsonb);
  v_sales_type_id uuid :=
    NULLIF(sale_payload ->> 'sales_type_id', '')::uuid;
  packaging_payload jsonb;
BEGIN
  IF v_sales_type_id IS NULL THEN
    RETURN;
  END IF;

  FOR packaging_payload IN
    SELECT movement.value
      FROM jsonb_array_elements(
        COALESCE(p_payload -> 'packaging_movements', '[]'::jsonb)
      ) AS movement(value)
      JOIN public.packaging_items item
        ON item.id = NULLIF(movement.value ->> 'packaging_item_id', '')::uuid
       AND item.restaurant_id = p_restaurant_id
     WHERE item.is_active = true
       AND item.tracks_stock = false
       AND EXISTS (
         SELECT 1
           FROM jsonb_array_elements(
             COALESCE(p_payload -> 'items', '[]'::jsonb)
           ) AS sale_item(value)
           JOIN public.product_packaging_rules rule
             ON rule.product_id =
                NULLIF(sale_item.value ->> 'product_id', '')::uuid
            AND rule.restaurant_id = p_restaurant_id
          WHERE rule.sales_type_id = v_sales_type_id
            AND rule.packaging_item_id =
                NULLIF(movement.value ->> 'packaging_item_id', '')::uuid
            AND rule.is_active = true
       )
  LOOP
    IF NOT EXISTS (
      SELECT 1
        FROM public.packaging_movements
       WHERE id = packaging_payload ->> 'id'
    ) THEN
      INSERT INTO public.packaging_movements (
        id,
        restaurant_id,
        packaging_item_id,
        movement_type,
        quantity_delta,
        reference_type,
        reference_id,
        user_id,
        notes,
        unit_cost,
        created_at
      )
      VALUES (
        packaging_payload ->> 'id',
        p_restaurant_id,
        NULLIF(packaging_payload ->> 'packaging_item_id', '')::uuid,
        packaging_payload ->> 'movement_type',
        (packaging_payload ->> 'quantity_delta')::integer,
        packaging_payload ->> 'reference_type',
        packaging_payload ->> 'reference_id',
        packaging_payload ->> 'user_id',
        packaging_payload ->> 'notes',
        COALESCE((packaging_payload ->> 'unit_cost')::numeric, 0),
        COALESCE(
          NULLIF(packaging_payload ->> 'created_at', '')::timestamptz,
          now()
        )
      );
    END IF;
  END LOOP;
END;
$$;
