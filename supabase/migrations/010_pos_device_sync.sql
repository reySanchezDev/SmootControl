CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.pos_devices (
  id uuid PRIMARY KEY,
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  name text,
  secret_hash text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_by_user_id uuid REFERENCES auth.users(id),
  last_seen_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.pos_devices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pos_devices_same_restaurant ON public.pos_devices;
CREATE POLICY pos_devices_same_restaurant
  ON public.pos_devices
  FOR SELECT TO authenticated
  USING (public.is_same_restaurant(restaurant_id));

CREATE OR REPLACE FUNCTION public.register_pos_device(
  p_restaurant_id uuid,
  p_device_id uuid,
  p_device_secret text,
  p_name text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  has_permission boolean;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Usuario remoto requerido para registrar dispositivo'
      USING ERRCODE = '42501';
  END IF;

  SELECT EXISTS (
    SELECT 1
      FROM public.profiles profile
      JOIN public.role_permissions role_permission
        ON role_permission.role_id = profile.role_id
      JOIN public.permissions permission
        ON permission.id = role_permission.permission_id
     WHERE profile.id = auth.uid()
       AND profile.restaurant_id = p_restaurant_id
       AND profile.is_active = true
       AND permission.code = 'dispositivo.inicializar'
  )
    INTO has_permission;

  IF NOT has_permission THEN
    RAISE EXCEPTION 'No autorizado para registrar dispositivo POS'
      USING ERRCODE = '42501';
  END IF;

  IF p_device_secret IS NULL OR length(btrim(p_device_secret)) < 32 THEN
    RAISE EXCEPTION 'Credencial de dispositivo invalida'
      USING ERRCODE = '23514';
  END IF;

  INSERT INTO public.pos_devices (
    id,
    restaurant_id,
    name,
    secret_hash,
    is_active,
    created_by_user_id,
    created_at,
    updated_at
  )
  VALUES (
    p_device_id,
    p_restaurant_id,
    p_name,
    encode(digest(p_device_secret, 'sha256'), 'hex'),
    true,
    auth.uid(),
    now(),
    now()
  )
  ON CONFLICT (id) DO UPDATE
     SET restaurant_id = excluded.restaurant_id,
         name = excluded.name,
         secret_hash = excluded.secret_hash,
         is_active = true,
         updated_at = now();

  RETURN p_device_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.assert_pos_device(
  p_restaurant_id uuid,
  p_device_id uuid,
  p_device_secret text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM public.pos_devices
     WHERE id = p_device_id
       AND restaurant_id = p_restaurant_id
       AND is_active = true
       AND secret_hash = encode(digest(p_device_secret, 'sha256'), 'hex')
  ) THEN
    RAISE EXCEPTION 'Dispositivo POS no autorizado'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.pos_devices
     SET last_seen_at = now(),
         updated_at = now()
   WHERE id = p_device_id
     AND restaurant_id = p_restaurant_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.pos_sync_cash_register_session(
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
  session_id uuid;
  remote_session_id uuid;
  cashier_id uuid;
  business_day date;
  session_status text;
BEGIN
  PERFORM public.assert_pos_device(
    p_restaurant_id,
    p_device_id,
    p_device_secret
  );

  session_id := (p_payload ->> 'id')::uuid;
  cashier_id := (p_payload ->> 'cashier_user_id')::uuid;
  business_day := COALESCE(
    NULLIF(p_payload ->> 'business_date', '')::date,
    CURRENT_DATE
  );
  session_status := COALESCE(NULLIF(p_payload ->> 'status', ''), 'open');

  IF session_status = 'open' THEN
    SELECT id
      INTO remote_session_id
      FROM public.cash_register_sessions
     WHERE restaurant_id = p_restaurant_id
       AND cashier_user_id = cashier_id
       AND business_date = business_day
       AND status = 'open'
     LIMIT 1;

    IF remote_session_id IS NOT NULL AND remote_session_id <> session_id THEN
      RETURN jsonb_build_object(
        'remote_id', remote_session_id,
        'aliased', true
      );
    END IF;
  END IF;

  IF session_status = 'closed' THEN
    SELECT id
      INTO remote_session_id
      FROM public.cash_register_sessions
     WHERE id = session_id
       AND restaurant_id = p_restaurant_id
     LIMIT 1;

    IF remote_session_id IS NULL THEN
      SELECT id
        INTO remote_session_id
        FROM public.cash_register_sessions
       WHERE restaurant_id = p_restaurant_id
         AND cashier_user_id = cashier_id
         AND business_date = business_day
         AND status = 'open'
       LIMIT 1;
    END IF;

    session_id := COALESCE(remote_session_id, session_id);
  END IF;

  INSERT INTO public.cash_register_sessions (
    id,
    restaurant_id,
    cashier_user_id,
    business_date,
    opening_cash_amount,
    counted_cash_amount,
    status,
    closed_at,
    updated_at
  )
  VALUES (
    session_id,
    p_restaurant_id,
    cashier_id,
    business_day,
    COALESCE((p_payload ->> 'opening_cash_amount')::numeric, 0),
    NULLIF(p_payload ->> 'counted_cash_amount', '')::numeric,
    session_status,
    CASE
      WHEN session_status = 'closed' THEN COALESCE(
        NULLIF(p_payload ->> 'closed_at', '')::timestamptz,
        now()
      )
      ELSE NULL
    END,
    now()
  )
  ON CONFLICT (id) DO UPDATE
     SET opening_cash_amount = excluded.opening_cash_amount,
         counted_cash_amount = excluded.counted_cash_amount,
         status = excluded.status,
         closed_at = excluded.closed_at,
         updated_at = now();

  RETURN jsonb_build_object('remote_id', session_id, 'aliased', false);
END;
$$;

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
BEGIN
  PERFORM public.assert_pos_device(
    p_restaurant_id,
    p_device_id,
    p_device_secret
  );

  sale_payload := p_payload -> 'sale';
  sale_id := (sale_payload ->> 'id')::uuid;
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
    sale_payload ->> 'local_id',
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
    sale_payload ->> 'invoice_number',
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
       SET quantity = excluded.quantity,
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
        unit_cost,
        reference_type,
        reference_id,
        user_id,
        notes,
        created_at
      )
      VALUES (
        packaging_payload ->> 'id',
        p_restaurant_id,
        (packaging_payload ->> 'packaging_item_id')::uuid,
        packaging_payload ->> 'movement_type',
        (packaging_payload ->> 'quantity_delta')::integer,
        COALESCE((packaging_payload ->> 'unit_cost')::numeric, 0),
        packaging_payload ->> 'reference_type',
        packaging_payload ->> 'reference_id',
        packaging_payload ->> 'user_id',
        packaging_payload ->> 'notes',
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

  void_payload := COALESCE(p_payload -> 'void', '{}'::jsonb);
  IF jsonb_typeof(void_payload) = 'object' AND void_payload <> '{}'::jsonb THEN
    INSERT INTO public.sale_voids (
      sale_id,
      restaurant_id,
      cash_register_session_id,
      voided_by_user_id,
      reason,
      original_total_amount,
      original_payment_method_id,
      original_payment_reference,
      sync_status,
      voided_at
    )
    VALUES (
      sale_id,
      p_restaurant_id,
      cash_session_id,
      cashier_id,
      COALESCE(void_payload ->> 'reason', 'Anulacion local'),
      (sale_payload ->> 'total_amount')::numeric,
      (sale_payload ->> 'payment_method_id')::uuid,
      sale_payload ->> 'payment_reference',
      'synced',
      now()
    )
    ON CONFLICT (sale_id) DO UPDATE
       SET sync_status = 'synced';
  END IF;

  RETURN jsonb_build_object('remote_id', sale_id);
END;
$$;

REVOKE ALL ON FUNCTION public.register_pos_device(
  uuid,
  uuid,
  text,
  text
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assert_pos_device(uuid, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pos_sync_cash_register_session(
  uuid,
  uuid,
  text,
  jsonb
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pos_sync_sale(
  uuid,
  uuid,
  text,
  jsonb
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.register_pos_device(uuid, uuid, text, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.pos_sync_cash_register_session(
  uuid,
  uuid,
  text,
  jsonb
) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.pos_sync_sale(
  uuid,
  uuid,
  text,
  jsonb
) TO anon, authenticated;
