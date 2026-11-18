-- Remove POS packaging rule reads from products/product_id.
BEGIN;

UPDATE public.items item
SET base_unit_id = unit.id, updated_at = now()
FROM public.packaging_items packaging
JOIN public.measurement_units unit ON unit.code = 'unit'
WHERE item.id = packaging.id AND item.base_unit_id IS NULL;

INSERT INTO public.item_consumption_rules(
  id, restaurant_id, source_item_id, consumed_item_id, sales_type_id, scope,
  quantity, unit_id, priority, is_active
)
SELECT rule.id, rule.restaurant_id, rule.product_id, rule.packaging_item_id,
  rule.sales_type_id, 'per_sale_line', rule.quantity_per_unit,
  packaging_item.base_unit_id, 100, rule.is_active
FROM public.product_packaging_rules rule
JOIN public.items source_item ON source_item.id = rule.product_id
  AND source_item.restaurant_id = rule.restaurant_id
JOIN public.items packaging_item ON packaging_item.id = rule.packaging_item_id
  AND packaging_item.restaurant_id = rule.restaurant_id
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.pos_sale_payload_for_current_stock_rules(
  p_restaurant_id uuid, p_payload jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  sale_payload jsonb := coalesce(p_payload -> 'sale', '{}'::jsonb);
  v_sales_type_id uuid := nullif(sale_payload ->> 'sales_type_id', '')::uuid;
  inventory_payload jsonb;
  packaging_payload jsonb;
BEGIN
  SELECT coalesce(jsonb_agg(movement.value), '[]'::jsonb) INTO inventory_payload
  FROM jsonb_array_elements(coalesce(p_payload -> 'inventory_movements', '[]')) movement(value)
  JOIN public.items item ON item.id = nullif(movement.value ->> 'item_id', '')::uuid
    AND item.restaurant_id = p_restaurant_id
  WHERE item.tracks_inventory AND NOT item.uses_recipe;

  SELECT coalesce(jsonb_agg(movement.value), '[]'::jsonb) INTO packaging_payload
  FROM jsonb_array_elements(coalesce(p_payload -> 'packaging_movements', '[]')) movement(value)
  JOIN public.packaging_items packaging ON packaging.id =
    nullif(movement.value ->> 'packaging_item_id', '')::uuid
    AND packaging.restaurant_id = p_restaurant_id
  WHERE packaging.is_active AND packaging.tracks_stock AND v_sales_type_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM jsonb_array_elements(coalesce(p_payload -> 'items', '[]')) sale(value)
      JOIN public.item_consumption_rules rule ON rule.source_item_id =
        nullif(coalesce(sale.value ->> 'item_id', sale.value ->> 'product_id'), '')::uuid
        AND rule.consumed_item_id = packaging.id
        AND rule.restaurant_id = p_restaurant_id
      WHERE rule.sales_type_id = v_sales_type_id AND rule.is_active
    );
  RETURN jsonb_set(jsonb_set(p_payload, '{inventory_movements}', inventory_payload, true),
    '{packaging_movements}', packaging_payload, true);
END;
$$;

CREATE OR REPLACE FUNCTION public.pos_record_nontracked_packaging_movements(
  p_restaurant_id uuid, p_payload jsonb
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  sale_payload jsonb := coalesce(p_payload -> 'sale', '{}'::jsonb);
  v_sales_type_id uuid := nullif(sale_payload ->> 'sales_type_id', '')::uuid;
  movement jsonb;
BEGIN
  IF v_sales_type_id IS NULL THEN RETURN; END IF;
  FOR movement IN
    SELECT movement.value
    FROM jsonb_array_elements(coalesce(p_payload -> 'packaging_movements', '[]')) movement(value)
    JOIN public.packaging_items packaging ON packaging.id =
      nullif(movement.value ->> 'packaging_item_id', '')::uuid
      AND packaging.restaurant_id = p_restaurant_id
    WHERE packaging.is_active AND NOT packaging.tracks_stock
      AND EXISTS (
        SELECT 1 FROM jsonb_array_elements(coalesce(p_payload -> 'items', '[]')) sale(value)
        JOIN public.item_consumption_rules rule ON rule.source_item_id =
          nullif(coalesce(sale.value ->> 'item_id', sale.value ->> 'product_id'), '')::uuid
          AND rule.consumed_item_id = packaging.id
          AND rule.restaurant_id = p_restaurant_id
        WHERE rule.sales_type_id = v_sales_type_id AND rule.is_active
      )
  LOOP
    INSERT INTO public.packaging_movements(
      id, restaurant_id, packaging_item_id, movement_type, quantity_delta,
      reference_type, reference_id, user_id, notes, unit_cost, created_at
    ) VALUES (
      movement ->> 'id', p_restaurant_id,
      nullif(movement ->> 'packaging_item_id', '')::uuid,
      movement ->> 'movement_type', (movement ->> 'quantity_delta')::integer,
      movement ->> 'reference_type', movement ->> 'reference_id',
      movement ->> 'user_id', movement ->> 'notes',
      coalesce((movement ->> 'unit_cost')::numeric, 0),
      coalesce(nullif(movement ->> 'created_at', '')::timestamptz, now())
    ) ON CONFLICT (id) DO NOTHING;
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.pos_sale_payload_for_current_stock_rules(uuid,jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pos_record_nontracked_packaging_movements(uuid,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pos_sale_payload_for_current_stock_rules(uuid,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pos_record_nontracked_packaging_movements(uuid,jsonb) TO authenticated;
COMMIT;
