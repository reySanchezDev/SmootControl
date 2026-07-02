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
  sale_payload jsonb;
  item_payload jsonb;
  inventory_payload jsonb;
  packaging_payload jsonb;
  void_payload jsonb;
  sale_id uuid;
  cash_session_id uuid;
  cashier_id uuid;
  business_day date;
  current_quantity integer;
  next_quantity integer;
  invoice_text text;
  original_invoice_text text;
  local_sale_id text;
  existing_sale_id uuid;
  existing_local_id text;
  invoice_prefix text;
  invoice_sequence bigint;
  invoice_separator text;
  renumbered_invoice boolean := false;
BEGIN
  PERFORM public.assert_pos_device(
    p_restaurant_id,
    p_device_id,
    p_device_secret
  );

  sale_payload := p_payload -> 'sale';
  sale_id := (sale_payload ->> 'id')::uuid;
  local_sale_id := sale_payload ->> 'local_id';
  original_invoice_text := sale_payload ->> 'invoice_number';
  invoice_text := original_invoice_text;
  cash_session_id := NULLIF(
    sale_payload ->> 'cash_register_session_id',
    ''
  )::uuid;
  cashier_id := (sale_payload ->> 'user_id')::uuid;
  business_day := NULLIF(sale_payload ->> 'business_date', '')::date;

  IF cash_session_id IS NOT NULL AND NOT EXISTS (
    SELECT 1
      FROM public.cash_register_sessions
     WHERE id = cash_session_id
       AND restaurant_id = p_restaurant_id
  ) THEN
    cash_session_id := NULL;
  END IF;

  IF cash_session_id IS NULL THEN
    SELECT id
      INTO cash_session_id
      FROM public.cash_register_sessions
     WHERE restaurant_id = p_restaurant_id
       AND cashier_user_id = cashier_id
       AND business_date = COALESCE(business_day, CURRENT_DATE)
       AND status = 'open'
     LIMIT 1;
  END IF;

  IF cash_session_id IS NULL THEN
    RAISE EXCEPTION 'No existe caja remota abierta para sincronizar venta'
      USING ERRCODE = '23503';
  END IF;

  SELECT id, local_id
    INTO existing_sale_id, existing_local_id
    FROM public.sales
   WHERE restaurant_id = p_restaurant_id
     AND invoice_number = invoice_text
   LIMIT 1;

  IF existing_sale_id IS NOT NULL AND existing_sale_id <> sale_id THEN
    IF existing_local_id IS NOT DISTINCT FROM local_sale_id THEN
      sale_id := existing_sale_id;
    ELSE
      SELECT COALESCE(prefix, 'F'), next_number
        INTO invoice_prefix, invoice_sequence
        FROM public.invoice_number_settings
       WHERE restaurant_id = p_restaurant_id
       FOR UPDATE;

      invoice_prefix := COALESCE(NULLIF(invoice_prefix, ''), 'F');
      invoice_separator := CASE
        WHEN right(invoice_prefix, 1) = '-' THEN ''
        ELSE '-'
      END;

      SELECT GREATEST(
               COALESCE(invoice_sequence, 1),
               COALESCE(
                 MAX(NULLIF(substring(invoice_number FROM '([0-9]+)$'), '')::bigint),
                 0
               ) + 1
             )
        INTO invoice_sequence
        FROM public.sales
       WHERE restaurant_id = p_restaurant_id;

      LOOP
        invoice_text := invoice_prefix || invoice_separator || invoice_sequence;
        EXIT WHEN NOT EXISTS (
          SELECT 1
            FROM public.sales
           WHERE restaurant_id = p_restaurant_id
             AND invoice_number = invoice_text
        );
        invoice_sequence := invoice_sequence + 1;
      END LOOP;

      renumbered_invoice := true;
    END IF;
  END IF;

  INSERT INTO public.sales (
    id,
    local_id,
    restaurant_id,
    cash_register_session_id,
    table_id,
    table_account_id,
    account_name,
    user_id,
    payment_method_id,
    sales_type_id,
    sales_type_name,
    payment_reference,
    invoice_number,
    total_amount,
    total_cost,
    gross_profit,
    status,
    sync_status,
    sold_at,
    updated_at
  )
  VALUES (
    sale_id,
    local_sale_id,
    p_restaurant_id,
    cash_session_id,
    NULLIF(sale_payload ->> 'table_id', '')::uuid,
    NULLIF(sale_payload ->> 'table_account_id', '')::uuid,
    sale_payload ->> 'account_name',
    cashier_id,
    (sale_payload ->> 'payment_method_id')::uuid,
    NULLIF(sale_payload ->> 'sales_type_id', '')::uuid,
    sale_payload ->> 'sales_type_name',
    sale_payload ->> 'payment_reference',
    invoice_text,
    (sale_payload ->> 'total_amount')::numeric,
    (sale_payload ->> 'total_cost')::numeric,
    (sale_payload ->> 'gross_profit')::numeric,
    COALESCE(sale_payload ->> 'status', 'completed'),
    'synced',
    COALESCE(
      NULLIF(sale_payload ->> 'sold_at', '')::timestamptz,
      now()
    ),
    now()
  )
  ON CONFLICT (id) DO UPDATE
     SET cash_register_session_id = excluded.cash_register_session_id,
         table_id = excluded.table_id,
         table_account_id = excluded.table_account_id,
         payment_method_id = excluded.payment_method_id,
         sales_type_id = excluded.sales_type_id,
         sales_type_name = excluded.sales_type_name,
         payment_reference = excluded.payment_reference,
         total_amount = excluded.total_amount,
         total_cost = excluded.total_cost,
         gross_profit = excluded.gross_profit,
         status = excluded.status,
         sync_status = 'synced',
         updated_at = now();

  invoice_sequence := NULLIF(substring(invoice_text FROM '([0-9]+)$'), '')::bigint;
  IF invoice_sequence IS NOT NULL THEN
    INSERT INTO public.invoice_number_settings (
      restaurant_id,
      prefix,
      initial_number,
      next_number,
      created_at,
      updated_at
    )
    VALUES (
      p_restaurant_id,
      COALESCE(NULLIF(substring(invoice_text FROM '^([^0-9]+)'), ''), 'F'),
      1,
      invoice_sequence + 1,
      now(),
      now()
    )
    ON CONFLICT (restaurant_id) DO UPDATE
       SET next_number = GREATEST(
             public.invoice_number_settings.next_number,
             excluded.next_number
           ),
           updated_at = now();
  END IF;

  FOR item_payload IN
    SELECT value FROM jsonb_array_elements(
      COALESCE(p_payload -> 'items', '[]'::jsonb)
    )
  LOOP
    INSERT INTO public.sale_items (
      id,
      sale_id,
      product_id,
      table_account_id,
      product_code,
      product_name,
      category_name,
      selected_options_label,
      quantity,
      unit_price,
      unit_cost,
      subtotal,
      gross_profit,
      created_at
    )
    VALUES (
      (item_payload ->> 'id')::uuid,
      sale_id,
      NULLIF(item_payload ->> 'product_id', '')::uuid,
      NULLIF(item_payload ->> 'table_account_id', '')::uuid,
      item_payload ->> 'product_code',
      item_payload ->> 'product_name',
      item_payload ->> 'category_name',
      item_payload ->> 'selected_options_label',
      (item_payload ->> 'quantity')::numeric,
      (item_payload ->> 'unit_price')::numeric,
      (item_payload ->> 'unit_cost')::numeric,
      (item_payload ->> 'subtotal')::numeric,
      (item_payload ->> 'gross_profit')::numeric,
      COALESCE(
        NULLIF(item_payload ->> 'created_at', '')::timestamptz,
        now()
      )
    )
    ON CONFLICT (id) DO UPDATE
       SET sale_id = excluded.sale_id,
           quantity = excluded.quantity,
           unit_price = excluded.unit_price,
           unit_cost = excluded.unit_cost,
           subtotal = excluded.subtotal,
           gross_profit = excluded.gross_profit;
  END LOOP;

  FOR inventory_payload IN
    SELECT value FROM jsonb_array_elements(
      COALESCE(p_payload -> 'inventory_movements', '[]'::jsonb)
    )
  LOOP
    IF NOT EXISTS (
      SELECT 1
        FROM public.inventory_movements
       WHERE id = inventory_payload ->> 'id'
    ) THEN
      INSERT INTO public.inventory_stock (
        restaurant_id,
        product_id,
        quantity_on_hand,
        created_at,
        updated_at
      )
      VALUES (
        p_restaurant_id,
        (inventory_payload ->> 'product_id')::uuid,
        0,
        now(),
        now()
      )
      ON CONFLICT (restaurant_id, product_id) DO NOTHING;

      SELECT quantity_on_hand
        INTO current_quantity
        FROM public.inventory_stock
       WHERE restaurant_id = p_restaurant_id
         AND product_id = (inventory_payload ->> 'product_id')::uuid
       FOR UPDATE;

      next_quantity := current_quantity +
        (inventory_payload ->> 'quantity_delta')::integer;
      IF next_quantity < 0 THEN
        RAISE EXCEPTION 'Stock insuficiente para producto remoto'
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
        inventory_payload ->> 'id',
        p_restaurant_id,
        (inventory_payload ->> 'product_id')::uuid,
        inventory_payload ->> 'movement_type',
        (inventory_payload ->> 'quantity_delta')::integer,
        inventory_payload ->> 'reference_type',
        inventory_payload ->> 'reference_id',
        inventory_payload ->> 'user_id',
        inventory_payload ->> 'notes',
        COALESCE(
          NULLIF(inventory_payload ->> 'created_at', '')::timestamptz,
          now()
        )
      );

      UPDATE public.inventory_stock
         SET quantity_on_hand = next_quantity,
             updated_at = now()
       WHERE restaurant_id = p_restaurant_id
         AND product_id = (inventory_payload ->> 'product_id')::uuid;
    END IF;
  END LOOP;

  FOR packaging_payload IN
    SELECT value FROM jsonb_array_elements(
      COALESCE(p_payload -> 'packaging_movements', '[]'::jsonb)
    )
  LOOP
    IF NOT EXISTS (
      SELECT 1
        FROM public.packaging_movements
       WHERE id = packaging_payload ->> 'id'
    ) THEN
      INSERT INTO public.packaging_stock (
        restaurant_id,
        packaging_item_id,
        quantity_on_hand,
        created_at,
        updated_at
      )
      VALUES (
        p_restaurant_id,
        (packaging_payload ->> 'packaging_item_id')::uuid,
        0,
        now(),
        now()
      )
      ON CONFLICT (restaurant_id, packaging_item_id) DO NOTHING;

      SELECT quantity_on_hand
        INTO current_quantity
        FROM public.packaging_stock
       WHERE restaurant_id = p_restaurant_id
         AND packaging_item_id =
           (packaging_payload ->> 'packaging_item_id')::uuid
       FOR UPDATE;

      next_quantity := current_quantity +
        (packaging_payload ->> 'quantity_delta')::integer;
      IF next_quantity < 0 THEN
        RAISE EXCEPTION 'Stock insuficiente para empaque remoto'
          USING ERRCODE = '23514';
      END IF;

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
        (packaging_payload ->> 'packaging_item_id')::uuid,
        packaging_payload ->> 'movement_type',
        (packaging_payload ->> 'quantity_delta')::integer,
        packaging_payload ->> 'reference_type',
        packaging_payload ->> 'reference_id',
        packaging_payload ->> 'user_id',
        packaging_payload ->> 'notes',
        COALESCE(
          (packaging_payload ->> 'unit_cost')::numeric,
          0
        ),
        COALESCE(
          NULLIF(packaging_payload ->> 'created_at', '')::timestamptz,
          now()
        )
      );

      UPDATE public.packaging_stock
         SET quantity_on_hand = next_quantity,
             updated_at = now()
       WHERE restaurant_id = p_restaurant_id
         AND packaging_item_id =
           (packaging_payload ->> 'packaging_item_id')::uuid;
    END IF;
  END LOOP;

  void_payload := p_payload -> 'void';
  IF void_payload IS NOT NULL AND void_payload <> '{}'::jsonb THEN
    INSERT INTO public.sale_voids (
      sale_id,
      restaurant_id,
      voided_by_user_id,
      reason,
      voided_at
    )
    VALUES (
      sale_id,
      p_restaurant_id,
      cashier_id,
      void_payload ->> 'reason',
      now()
    )
    ON CONFLICT (sale_id) DO UPDATE
       SET reason = excluded.reason,
           voided_by_user_id = excluded.voided_by_user_id,
           voided_at = excluded.voided_at;
  END IF;

  RETURN jsonb_build_object(
    'remote_id', sale_id,
    'invoice_number', invoice_text,
    'original_invoice_number', original_invoice_text,
    'renumbered_invoice', renumbered_invoice
  );
END;
$$;

COMMENT ON FUNCTION public.pos_sync_sale(
  uuid,
  uuid,
  text,
  jsonb
) IS
  'Synchronizes one POS sale idempotently and advances remote invoice numbering.';
