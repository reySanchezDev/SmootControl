-- Canonical administrative purchase and adjustment contracts.
ALTER TABLE public.inventory_adjustment_lines
  ALTER COLUMN product_id DROP NOT NULL;

CREATE OR REPLACE FUNCTION public.app_register_inventory_purchase_batch_v2(
  p_restaurant_id uuid,
  p_items jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  row_payload jsonb;
  v_item_id uuid;
  quantity numeric;
  purchase_cost numeric;
  base_quantity numeric;
  base_cost numeric;
  purchase_unit_id uuid;
  movement_id text;
  item_count integer := 0;
  item_row public.items%ROWTYPE;
BEGIN
  PERFORM public.app_assert_admin_permission(p_restaurant_id, 'inventario.gestionar');
  IF jsonb_typeof(COALESCE(p_items, '[]'::jsonb)) <> 'array' THEN
    RAISE EXCEPTION 'Lista de artículos inválida' USING ERRCODE = '22023';
  END IF;
  FOR row_payload IN SELECT value FROM jsonb_array_elements(COALESCE(p_items, '[]'::jsonb)) LOOP
    v_item_id := (row_payload ->> 'item_id')::uuid;
    quantity := (row_payload ->> 'quantity')::numeric;
    purchase_cost := (row_payload ->> 'unit_cost')::numeric;
    purchase_unit_id := NULLIF(row_payload ->> 'purchase_unit_id', '')::uuid;
    SELECT * INTO item_row FROM public.items i
    WHERE i.id = v_item_id AND i.restaurant_id = p_restaurant_id
      AND i.is_active AND i.tracks_inventory;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Artículo remoto no activo o no controla inventario: %', v_item_id
        USING ERRCODE = '23503';
    END IF;
    IF quantity IS NULL OR quantity <= 0 OR purchase_cost IS NULL OR purchase_cost < 0 THEN
      RAISE EXCEPTION 'Cantidad o costo de artículo inválido' USING ERRCODE = '23514';
    END IF;
    base_quantity := quantity;
    base_cost := purchase_cost;
    IF purchase_unit_id IS NOT NULL THEN
      IF item_row.purchase_unit_id IS NULL OR item_row.purchase_to_base_factor IS NULL
         OR item_row.purchase_to_base_factor <= 0 OR purchase_unit_id <> item_row.purchase_unit_id THEN
        RAISE EXCEPTION 'Unidad de compra no coincide para artículo: %', v_item_id
          USING ERRCODE = '23514';
      END IF;
      base_quantity := quantity * item_row.purchase_to_base_factor;
      base_cost := purchase_cost / item_row.purchase_to_base_factor;
    END IF;
    movement_id := COALESCE(NULLIF(row_payload ->> 'movement_id', ''), gen_random_uuid()::text);
    PERFORM public.apply_inventory_movement_v2(
      movement_id, p_restaurant_id, v_item_id, NULL, 'purchase', base_quantity,
      'admin_batch_purchase', movement_id, auth.uid()::text, NULL, now(), base_cost
    );
    UPDATE public.items SET base_unit_cost = purchase_cost, unit_cost = purchase_cost,
      updated_at = now() WHERE id = v_item_id AND restaurant_id = p_restaurant_id;
    item_count := item_count + 1;
  END LOOP;
  IF item_count = 0 THEN
    RAISE EXCEPTION 'No hay artículos para registrar' USING ERRCODE = '23514';
  END IF;
  RETURN jsonb_build_object('item_count', item_count);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_register_inventory_adjustment_batch_v2(
  p_restaurant_id uuid,
  p_items jsonb,
  p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  row_payload jsonb;
  v_item_id uuid;
  expected_quantity numeric(18,6);
  counted_quantity numeric(18,6);
  entered_quantity numeric(18,6);
  entered_unit_id uuid;
  current_quantity numeric(18,6);
  quantity_delta numeric(18,6);
  movement_id text;
  document_id uuid;
  document_number bigint;
  item_count integer := 0;
BEGIN
  PERFORM public.app_assert_admin_permission(p_restaurant_id, 'inventario.gestionar');
  IF jsonb_typeof(COALESCE(p_items, '[]'::jsonb)) <> 'array' THEN
    RAISE EXCEPTION 'Lista de ajuste inválida' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.inventory_adjustment_number_settings(restaurant_id,next_number,updated_at)
  VALUES (p_restaurant_id,1,now()) ON CONFLICT (restaurant_id) DO NOTHING;
  UPDATE public.inventory_adjustment_number_settings
  SET next_number = next_number + 1, updated_at = now()
  WHERE restaurant_id = p_restaurant_id
  RETURNING next_number - 1 INTO document_number;
  INSERT INTO public.inventory_adjustment_documents(
    restaurant_id,document_number,note,created_by_user_id,created_at
  ) VALUES (
    p_restaurant_id,document_number,NULLIF(btrim(COALESCE(p_note,'')),''),auth.uid(),now()
  ) RETURNING id INTO document_id;
  FOR row_payload IN SELECT value FROM jsonb_array_elements(COALESCE(p_items, '[]'::jsonb)) LOOP
    v_item_id := (row_payload ->> 'item_id')::uuid;
    expected_quantity := (row_payload ->> 'expected_quantity')::numeric;
    counted_quantity := (row_payload ->> 'counted_quantity')::numeric;
    entered_quantity := NULLIF(row_payload ->> 'entered_count_quantity','')::numeric;
    entered_unit_id := NULLIF(row_payload ->> 'entered_count_unit_id','')::uuid;
    IF counted_quantity IS NULL OR counted_quantity < 0 OR expected_quantity IS NULL OR expected_quantity < 0 THEN
      RAISE EXCEPTION 'Conteo de artículo inválido' USING ERRCODE = '23514';
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM public.items i WHERE i.id = v_item_id AND i.restaurant_id = p_restaurant_id
        AND i.is_active AND i.tracks_inventory
    ) THEN
      RAISE EXCEPTION 'Artículo remoto no activo o no controla inventario: %', v_item_id
        USING ERRCODE = '23503';
    END IF;
    INSERT INTO public.inventory_stock(restaurant_id,product_id,item_id,quantity_on_hand,created_at,updated_at)
    VALUES (p_restaurant_id,NULL,v_item_id,0,now(),now())
    ON CONFLICT (restaurant_id,item_id) DO NOTHING;
    SELECT quantity_on_hand INTO current_quantity FROM public.inventory_stock
    WHERE restaurant_id = p_restaurant_id AND inventory_stock.item_id = v_item_id FOR UPDATE;
    IF current_quantity <> expected_quantity THEN
      RAISE EXCEPTION 'El stock remoto cambió. Refresca el inventario.' USING ERRCODE = '40001';
    END IF;
    quantity_delta := counted_quantity - current_quantity;
    IF quantity_delta = 0 THEN CONTINUE; END IF;
    movement_id := COALESCE(NULLIF(row_payload ->> 'movement_id',''),gen_random_uuid()::text);
    INSERT INTO public.inventory_adjustment_lines(
      document_id,restaurant_id,product_id,item_id,stock_before,counted_quantity,
      quantity_delta,entered_count_quantity,entered_count_unit_id,created_at
    ) VALUES (
      document_id,p_restaurant_id,NULL,v_item_id,current_quantity,counted_quantity,
      quantity_delta,entered_quantity,entered_unit_id,now()
    );
    PERFORM public.apply_inventory_movement_v2(
      movement_id,p_restaurant_id,v_item_id,NULL,'adjustment',quantity_delta,
      'inventory_adjustment',document_id::text,auth.uid()::text,
      NULLIF(btrim(COALESCE(p_note,'')),''),now(),0
    );
    item_count := item_count + 1;
  END LOOP;
  IF item_count = 0 THEN
    RAISE EXCEPTION 'No hay cambios de inventario para registrar' USING ERRCODE = '23514';
  END IF;
  RETURN jsonb_build_object('document_id',document_id,'document_number',document_number,'item_count',item_count);
END;
$$;

REVOKE ALL ON FUNCTION public.app_register_inventory_purchase_batch_v2(uuid,jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.app_register_inventory_adjustment_batch_v2(uuid,jsonb,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.app_register_inventory_purchase_batch_v2(uuid,jsonb) TO authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.app_register_inventory_adjustment_batch_v2(uuid,jsonb,text) TO authenticated,service_role;
