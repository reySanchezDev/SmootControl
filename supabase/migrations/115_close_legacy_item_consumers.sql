-- Close unused legacy RPC entry points and complete canonical item backfills.
BEGIN;

UPDATE public.employee_raw_material_consumption_lines
SET item_id = product_id
WHERE item_id IS NULL AND product_id IS NOT NULL;

UPDATE public.inventory_adjustment_lines
SET item_id = product_id
WHERE item_id IS NULL AND product_id IS NOT NULL;

UPDATE public.inventory_movements
SET item_id = product_id
WHERE item_id IS NULL AND product_id IS NOT NULL;

UPDATE public.inventory_stock
SET item_id = product_id
WHERE item_id IS NULL AND product_id IS NOT NULL;

UPDATE public.sale_items
SET item_id = product_id
WHERE item_id IS NULL AND product_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.apply_inventory_movement(
  p_id text, p_restaurant_id uuid, p_product_id uuid, p_movement_type text,
  p_quantity_delta numeric, p_reference_type text DEFAULT NULL,
  p_reference_id text DEFAULT NULL, p_user_id text DEFAULT NULL,
  p_notes text DEFAULT NULL, p_created_at timestamptz DEFAULT NULL,
  p_unit_cost numeric DEFAULT 0
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
BEGIN
  PERFORM public.apply_inventory_movement_v2(
    p_id, p_restaurant_id, p_product_id, p_product_id, p_movement_type,
    p_quantity_delta, p_reference_type, p_reference_id, p_user_id, p_notes,
    p_created_at, p_unit_cost
  );
END;
$$;

DROP FUNCTION IF EXISTS public.app_register_inventory_adjustment_batch(uuid,jsonb,text);
DROP FUNCTION IF EXISTS public.app_register_inventory_purchase_batch(uuid,jsonb);
DROP FUNCTION IF EXISTS public.pos_pull_operational_catalog_legacy_20261117(uuid,uuid,text);

COMMIT;
