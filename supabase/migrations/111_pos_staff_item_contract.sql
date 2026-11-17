-- POS staff consumption core using canonical item identity.
CREATE OR REPLACE FUNCTION public.pos_sync_staff_consumption_core_20260708(
  p_restaurant_id uuid, p_device_id uuid, p_device_secret text, p_payload jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  sale_payload jsonb := p_payload -> 'sale';
  item_payload jsonb; movement_payload jsonb; packaging_payload jsonb;
  sale_id uuid := (sale_payload ->> 'id')::uuid;
  existing_sale_id uuid; receipt_number bigint; next_number bigint;
  current_quantity numeric; next_quantity numeric;
BEGIN
  PERFORM public.assert_pos_device(p_restaurant_id, p_device_id, p_device_secret);
  IF NOT EXISTS (SELECT 1 FROM public.employees WHERE id =
    (sale_payload ->> 'employee_id')::uuid AND restaurant_id = p_restaurant_id
    AND is_active) THEN
    RAISE EXCEPTION 'Empleado no activo para consumo de personal';
  END IF;
  SELECT id, internal_receipt_number INTO existing_sale_id, receipt_number
  FROM public.sales WHERE restaurant_id = p_restaurant_id AND
    (id = sale_id OR (sale_payload ->> 'local_id' IS NOT NULL
      AND local_id = sale_payload ->> 'local_id')) LIMIT 1;
  IF existing_sale_id IS NOT NULL THEN sale_id := existing_sale_id;
  ELSE
    INSERT INTO public.staff_consumption_number_settings(restaurant_id,next_number,created_at,updated_at)
      VALUES (p_restaurant_id,1,now(),now()) ON CONFLICT (restaurant_id) DO NOTHING;
    SELECT next_number INTO next_number FROM public.staff_consumption_number_settings
      WHERE restaurant_id = p_restaurant_id FOR UPDATE;
    UPDATE public.staff_consumption_number_settings SET next_number = next_number + 1,
      updated_at = now() WHERE restaurant_id = p_restaurant_id;
    receipt_number := next_number;
  END IF;
  INSERT INTO public.sales(
    id,local_id,restaurant_id,cash_register_session_id,table_id,table_account_id,
    account_name,user_id,payment_method_id,sales_type_id,sales_type_name,
    payment_reference,invoice_number,sale_kind,employee_id,internal_receipt_number,
    total_amount,total_cost,gross_profit,status,sync_status,sold_at,updated_at)
  VALUES (sale_id,sale_payload ->> 'local_id',p_restaurant_id,
    nullif(sale_payload ->> 'cash_register_session_id','')::uuid,
    nullif(sale_payload ->> 'table_id','')::uuid,
    nullif(sale_payload ->> 'table_account_id','')::uuid,
    sale_payload ->> 'account_name',(sale_payload ->> 'user_id')::uuid,
    (sale_payload ->> 'payment_method_id')::uuid,
    nullif(sale_payload ->> 'sales_type_id','')::uuid,
    sale_payload ->> 'sales_type_name',sale_payload ->> 'payment_reference',
    'CP-' || receipt_number,'staff_consumption',
    (sale_payload ->> 'employee_id')::uuid,receipt_number,
    (sale_payload ->> 'total_amount')::numeric,(sale_payload ->> 'total_cost')::numeric,
    (sale_payload ->> 'gross_profit')::numeric,coalesce(sale_payload ->> 'status','completed'),
    'synced',coalesce(nullif(sale_payload ->> 'sold_at','')::timestamptz,now()),now())
  ON CONFLICT (id) DO UPDATE SET total_amount=excluded.total_amount,
    total_cost=excluded.total_cost,gross_profit=excluded.gross_profit,
    sync_status='synced',updated_at=now();
  FOR item_payload IN SELECT value FROM jsonb_array_elements(coalesce(p_payload -> 'items','[]')) LOOP
    INSERT INTO public.sale_items(
      id,sale_id,item_id,product_id,table_account_id,product_code,product_name,
      category_name,selected_options_label,quantity,unit_price,unit_cost,subtotal,
      gross_profit,created_at)
    VALUES ((item_payload ->> 'id')::uuid,sale_id,
      nullif(coalesce(item_payload ->> 'item_id',item_payload ->> 'product_id'),'')::uuid,
      NULL,nullif(item_payload ->> 'table_account_id','')::uuid,
      item_payload ->> 'product_code',item_payload ->> 'product_name',
      item_payload ->> 'category_name',item_payload ->> 'selected_options_label',
      (item_payload ->> 'quantity')::numeric,(item_payload ->> 'unit_price')::numeric,
      (item_payload ->> 'unit_cost')::numeric,(item_payload ->> 'subtotal')::numeric,
      (item_payload ->> 'gross_profit')::numeric,
      coalesce(nullif(item_payload ->> 'created_at','')::timestamptz,now()))
    ON CONFLICT (id) DO UPDATE SET item_id=excluded.item_id,product_id=NULL,
      quantity=excluded.quantity,unit_price=excluded.unit_price,
      unit_cost=excluded.unit_cost,subtotal=excluded.subtotal,
      gross_profit=excluded.gross_profit;
  END LOOP;
  FOR movement_payload IN SELECT value FROM jsonb_array_elements(
    coalesce(p_payload -> 'inventory_movements','[]')) LOOP
    IF NOT EXISTS (SELECT 1 FROM public.inventory_movements
      WHERE id = movement_payload ->> 'id') THEN
      PERFORM public.apply_inventory_movement_v2(
        movement_payload ->> 'id',p_restaurant_id,
        nullif(coalesce(movement_payload ->> 'item_id',movement_payload ->> 'product_id'),'')::uuid,
        NULL,movement_payload ->> 'movement_type',
        (movement_payload ->> 'quantity_delta')::numeric,'staff_consumption',
        sale_id::text,movement_payload ->> 'user_id',movement_payload ->> 'notes',
        coalesce(nullif(movement_payload ->> 'created_at','')::timestamptz,now()),
        coalesce((movement_payload ->> 'unit_cost')::numeric,0));
    END IF;
  END LOOP;
  FOR packaging_payload IN SELECT value FROM jsonb_array_elements(
    coalesce(p_payload -> 'packaging_movements','[]')) LOOP
    IF NOT EXISTS (SELECT 1 FROM public.packaging_movements
      WHERE id = packaging_payload ->> 'id') THEN
      INSERT INTO public.packaging_stock(restaurant_id,packaging_item_id,quantity_on_hand,created_at,updated_at)
      VALUES (p_restaurant_id,(packaging_payload ->> 'packaging_item_id')::uuid,0,now(),now())
      ON CONFLICT (restaurant_id,packaging_item_id) DO NOTHING;
      SELECT quantity_on_hand INTO current_quantity FROM public.packaging_stock
      WHERE restaurant_id=p_restaurant_id AND packaging_item_id=(packaging_payload ->> 'packaging_item_id')::uuid FOR UPDATE;
      next_quantity := current_quantity + (packaging_payload ->> 'quantity_delta')::numeric;
      IF next_quantity < 0 THEN RAISE EXCEPTION 'Stock insuficiente para empaque remoto'; END IF;
      INSERT INTO public.packaging_movements(
        id,restaurant_id,packaging_item_id,movement_type,quantity_delta,reference_type,
        reference_id,user_id,notes,unit_cost,created_at)
      VALUES (packaging_payload ->> 'id',p_restaurant_id,
        (packaging_payload ->> 'packaging_item_id')::uuid,packaging_payload ->> 'movement_type',
        (packaging_payload ->> 'quantity_delta')::integer,'staff_consumption',sale_id,
        packaging_payload ->> 'user_id',packaging_payload ->> 'notes',
        coalesce((packaging_payload ->> 'unit_cost')::numeric,0),
        coalesce(nullif(packaging_payload ->> 'created_at','')::timestamptz,now()));
      UPDATE public.packaging_stock SET quantity_on_hand=next_quantity,updated_at=now()
      WHERE restaurant_id=p_restaurant_id AND packaging_item_id=(packaging_payload ->> 'packaging_item_id')::uuid;
    END IF;
  END LOOP;
  RETURN jsonb_build_object('remote_id',sale_id,'invoice_number','CP-' || receipt_number,
    'internal_receipt_number',receipt_number);
END;
$$;
