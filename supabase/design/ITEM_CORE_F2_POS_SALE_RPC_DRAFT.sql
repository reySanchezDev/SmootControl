-- KIVO F2 / POS SALE + VOID TRANSACTIONAL PROTOTYPE
-- REVIEW DRAFT ONLY: DO NOT DEPLOY OR MOVE INTO MIGRATIONS.
-- Requires F1 items/ledger + F2 sale schema + F2 internal stock engine.
-- Supports SIMPLE sale lines (base unit, no recipe/modifier/tax adjustments).
-- Unsupported scenarios are rejected instead of silently misaccounted.
-- Before any operational cutover: implement recipes, modifiers, pricing,
-- multi-currency, service modes and signed POS auth with full regression.
-- Business transaction writes are atomic in PostgreSQL (one RPC call).
-- Client must supply stable sale_id/line_id/occurred_at/operation_key on retry.

CREATE OR REPLACE FUNCTION public.pos_sync_sale_v2(
  p_restaurant_id uuid,
  p_device_id uuid,
  p_device_secret text,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
SET row_security = off
AS $$
DECLARE
  v_sale_id uuid;
  v_session uuid;
  v_cashier uuid;
  v_payment uuid;
  v_sales_type uuid;
  v_sold_at timestamptz;
  v_op text;
  v_digest text;
  v_existing public.sales;
  v_line jsonb;
  v_line_id uuid;
  v_item_id uuid;
  v_item public.items;
  v_qty numeric;
  v_total numeric := 0;
  v_cost numeric := 0;
  v_consumption jsonb;
  v_c record;
  v_m record;
  v_prefix text;
  v_number bigint;
  v_invoice text;
  v_category text;
BEGIN
  PERFORM public.assert_pos_device(
    p_restaurant_id,p_device_id,p_device_secret
  );

  IF p_payload IS NULL OR jsonb_typeof(p_payload)<>'object'
     OR COALESCE((p_payload->>'contract_version')::integer,0)<>2
     OR jsonb_typeof(p_payload->'lines')<>'array'
     OR jsonb_array_length(p_payload->'lines')=0
  THEN
    RAISE EXCEPTION 'invalid_sale_v2_payload' USING ERRCODE='22023';
  END IF;
  IF p_payload ? 'modifiers' OR p_payload ? 'tax_adjustments'
     OR p_payload ? 'exchange_rate' OR p_payload ? 'staff_consumption' THEN
    RAISE EXCEPTION 'unsupported_sale_v2_features'
      USING ERRCODE='22023';
  END IF;

  v_sale_id := NULLIF(p_payload->>'sale_id','')::uuid;
  v_session := NULLIF(p_payload->>'cash_register_session_id','')::uuid;
  v_payment := NULLIF(p_payload->>'payment_method_id','')::uuid;
  v_sales_type := NULLIF(p_payload->>'sales_type_id','')::uuid;
  v_sold_at := NULLIF(p_payload->>'sold_at','')::timestamptz;
  v_op := NULLIF(btrim(p_payload->>'operation_key'),'');
  IF v_sale_id IS NULL OR v_session IS NULL OR v_payment IS NULL
     OR v_sales_type IS NULL OR v_sold_at IS NULL OR v_op IS NULL THEN
    RAISE EXCEPTION 'incomplete_sale_v2_identity' USING ERRCODE='22023';
  END IF;

  -- Request fingerprint covers all authoritative client fields. Idempotent
  -- retries of one sale must use identical values, including timestamps.
  v_digest := md5(p_payload::text);

  -- Serialize exact operation-key races before checking for existing sale.
  PERFORM pg_advisory_xact_lock(
    hashtext(p_restaurant_id::text), hashtext(v_op)
  );

  SELECT * INTO v_existing
  FROM public.sales s
  WHERE s.restaurant_id=p_restaurant_id AND s.operation_key=v_op
  FOR UPDATE;
  IF v_existing.id IS NOT NULL THEN
    IF v_existing.operation_digest<>v_digest
       OR v_existing.id<>v_sale_id
       OR v_existing.pos_device_id IS DISTINCT FROM p_device_id THEN
      RAISE EXCEPTION 'sale_v2_idempotency_mismatch'
        USING ERRCODE='23514';
    END IF;
    RETURN jsonb_build_object(
      'sale_id',v_existing.id,'invoice_number',v_existing.invoice_number,
      'replayed',true,'contract_version',2
    );
  END IF;

  IF EXISTS (SELECT 1 FROM public.sales WHERE id=v_sale_id) THEN
    RAISE EXCEPTION 'sale_v2_id_collision' USING ERRCODE='23505';
  END IF;

  SELECT cash.cashier_user_id INTO v_cashier
  FROM public.cash_register_sessions cash
  WHERE cash.id=v_session AND cash.restaurant_id=p_restaurant_id
    AND cash.pos_device_id=p_device_id AND cash.status='open'
  FOR SHARE;
  IF v_cashier IS NULL OR auth.uid() IS DISTINCT FROM v_cashier THEN
    RAISE EXCEPTION 'sale_v2_cashier_or_session_not_authorized'
      USING ERRCODE='42501';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.payment_methods pm
    WHERE pm.id=v_payment AND pm.is_active
      AND (pm.restaurant_id IS NULL OR pm.restaurant_id=p_restaurant_id)
  ) OR NOT EXISTS (
    SELECT 1 FROM public.sales_types st
    WHERE st.id=v_sales_type AND st.restaurant_id=p_restaurant_id
      AND st.is_active
  ) THEN
    RAISE EXCEPTION 'sale_v2_payment_or_type_invalid'
      USING ERRCODE='23503';
  END IF;

  -- Validate whole sale before any DML. Simple base-unit sales only.
  FOR v_line IN SELECT value FROM jsonb_array_elements(p_payload->'lines')
  LOOP
    IF jsonb_typeof(v_line)<>'object' THEN
      RAISE EXCEPTION 'invalid_sale_v2_line' USING ERRCODE='22023';
    END IF;
    v_line_id := NULLIF(v_line->>'line_id','')::uuid;
    v_item_id := NULLIF(v_line->>'item_id','')::uuid;
    v_qty := NULLIF(v_line->>'quantity','')::numeric;
    IF v_line_id IS NULL OR v_item_id IS NULL OR v_qty IS NULL
       OR v_qty<=0 OR v_qty>1000000 THEN
      RAISE EXCEPTION 'invalid_sale_v2_line_identity_or_quantity'
        USING ERRCODE='22023';
    END IF;
    SELECT * INTO v_item FROM public.items i
    WHERE i.id=v_item_id AND i.restaurant_id=p_restaurant_id
      AND i.is_active AND i.can_sell;
    IF v_item.id IS NULL THEN
      RAISE EXCEPTION 'sale_v2_item_missing_or_unsellable'
        USING ERRCODE='23503';
    END IF;
    IF v_item.uses_recipe OR COALESCE(v_item.send_to_kitchen,false)
       OR (v_line ? 'modifiers') THEN
      RAISE EXCEPTION 'sale_v2_recipe_or_modifier_requires_f2_next'
        USING ERRCODE='22023';
    END IF;
    IF NULLIF(v_line->>'unit_id','')::uuid IS DISTINCT FROM
       v_item.base_unit_id THEN
      RAISE EXCEPTION 'sale_v2_requires_base_unit'
        USING ERRCODE='23514';
    END IF;
    IF (v_line ? 'unit_price') AND
       (v_line->>'unit_price')::numeric IS DISTINCT FROM
       v_item.base_unit_price THEN
      RAISE EXCEPTION 'sale_v2_price_snapshot_conflict'
        USING ERRCODE='23514';
    END IF;
    v_total := v_total + v_qty*v_item.base_unit_price;
    v_cost := v_cost + v_qty*v_item.base_unit_cost;
  END LOOP;

  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_payload->'lines') line
    GROUP BY (line->>'line_id')::uuid HAVING count(*)>1
  ) THEN
    RAISE EXCEPTION 'duplicate_sale_v2_line_id' USING ERRCODE='23514';
  END IF;

  SELECT COALESCE(jsonb_agg(to_jsonb(r)),'[]'::jsonb)
    INTO v_consumption
  FROM public.resolve_item_consumption(
    p_restaurant_id,v_sales_type,p_payload->'lines'
  ) r;

  SELECT v_cost+COALESCE(sum(
    (entry->>'quantity_base')::numeric * consumed.base_unit_cost
  ),0)
  INTO v_cost
  FROM jsonb_array_elements(v_consumption) entry
  JOIN public.items consumed
    ON consumed.id=(entry->>'consumed_item_id')::uuid
   AND consumed.restaurant_id=p_restaurant_id;

  INSERT INTO public.invoice_number_settings(
    restaurant_id,prefix,initial_number,next_number
  ) VALUES(p_restaurant_id,'F',1,1)
  ON CONFLICT (restaurant_id) DO NOTHING;

  SELECT COALESCE(NULLIF(prefix,''),'F'),next_number
    INTO v_prefix,v_number
  FROM public.invoice_number_settings
  WHERE restaurant_id=p_restaurant_id
  FOR UPDATE;

  LOOP
    v_invoice := v_prefix || CASE WHEN right(v_prefix,1)='-' THEN '' ELSE '-' END
                 || v_number::text;
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.sales s
      WHERE s.restaurant_id=p_restaurant_id
        AND s.invoice_number=v_invoice
    );
    v_number:=v_number+1;
  END LOOP;
  UPDATE public.invoice_number_settings
  SET next_number=v_number+1
  WHERE restaurant_id=p_restaurant_id;

  INSERT INTO public.sales(
    id,local_id,restaurant_id,cash_register_session_id,user_id,
    payment_method_id,sales_type_id,invoice_number,total_amount,
    total_cost,gross_profit,status,sync_status,sold_at,pos_device_id,
    operation_key,operation_digest,sync_contract_version
  ) VALUES(
    v_sale_id,v_sale_id::text,p_restaurant_id,v_session,v_cashier,
    v_payment,v_sales_type,v_invoice,v_total,v_cost,v_total-v_cost,
    'completed','synced',v_sold_at,p_device_id,v_op,v_digest,2
  );

  FOR v_line IN SELECT value FROM jsonb_array_elements(p_payload->'lines')
  LOOP
    v_line_id := (v_line->>'line_id')::uuid;
    v_item_id := (v_line->>'item_id')::uuid;
    v_qty := (v_line->>'quantity')::numeric;
    SELECT * INTO v_item FROM public.items i WHERE i.id=v_item_id
      AND i.restaurant_id=p_restaurant_id;
    SELECT COALESCE(c.name,'') INTO v_category
      FROM public.product_categories c WHERE c.id=v_item.category_id
        AND c.restaurant_id=p_restaurant_id;
    INSERT INTO public.sale_items(
      id,sale_id,restaurant_id,item_id,sync_contract_version,
      item_base_unit_id,item_unit_factor,product_code,product_name,
      category_id,category_name,quantity,unit_price,unit_cost,
      subtotal,gross_profit
    ) VALUES(
      v_line_id,v_sale_id,p_restaurant_id,v_item_id,2,
      v_item.base_unit_id,1,v_item.code,v_item.name,
      v_item.category_id,COALESCE(v_category,''),v_qty,
      v_item.base_unit_price,v_item.base_unit_cost,
      v_qty*v_item.base_unit_price,
      v_qty*(v_item.base_unit_price-v_item.base_unit_cost)
    );
  END LOOP;

  -- Use a single trusted stock engine in deterministic item order.
  -- No HTTP writes to headers, lines or stock outside this transaction.
  FOR v_m IN
    WITH direct_sale AS (
      SELECT i.id AS item_id,'sale'::text AS movement_type,
        -(line.value->>'quantity')::numeric AS quantity_delta,
        i.base_unit_cost AS unit_cost,
        'sale:'||v_sale_id::text||':line:'||(line.value->>'line_id') AS movement_id,
        'sale:'||v_op||':line:'||(line.value->>'line_id') AS operation_key
      FROM jsonb_array_elements(p_payload->'lines') line
      JOIN public.items i ON i.id=(line.value->>'item_id')::uuid
        AND i.restaurant_id=p_restaurant_id AND i.item_type='inventory'
    ),
    rule_sale AS (
      SELECT (entry.value->>'consumed_item_id')::uuid AS item_id,
        'packaging_consumption'::text AS movement_type,
        -(entry.value->>'quantity_base')::numeric AS quantity_delta,
        i.base_unit_cost AS unit_cost,
        'sale:'||v_sale_id::text||':rule:'||(entry.value->>'rule_id')
          ||':line:'||COALESCE(entry.value->>'sale_line_id','order') AS movement_id,
        'sale:'||v_op||':rule:'||(entry.value->>'rule_id')
          ||':line:'||COALESCE(entry.value->>'sale_line_id','order') AS operation_key
      FROM jsonb_array_elements(v_consumption) entry
      JOIN public.items i ON i.id=(entry.value->>'consumed_item_id')::uuid
        AND i.restaurant_id=p_restaurant_id
        AND i.item_type='inventory'
    )
    SELECT * FROM direct_sale
    UNION ALL SELECT * FROM rule_sale
    ORDER BY item_id,movement_id
  LOOP
    PERFORM item_core_internal.post_movement(
      v_m.movement_id,p_restaurant_id,v_m.item_id,
      v_m.movement_type,v_m.quantity_delta,'sale',v_sale_id::text,
      v_m.operation_key,v_m.unit_cost,
      NULL,p_device_id,v_cashier,v_sold_at
    );
  END LOOP;

  FOR v_c IN
    SELECT value FROM jsonb_array_elements(v_consumption)
  LOOP
    INSERT INTO public.sale_consumption_snapshots(
      restaurant_id,sale_id,sale_line_id,scope,consumed_item_id,rule_id,
      quantity_base,unit_cost_base,movement_id,is_inventory_consumption
    )
    SELECT p_restaurant_id,v_sale_id,
      NULLIF(v_c.value->>'sale_line_id','')::uuid,
      v_c.value->>'scope',(v_c.value->>'consumed_item_id')::uuid,
      (v_c.value->>'rule_id')::uuid,
      (v_c.value->>'quantity_base')::numeric,i.base_unit_cost,
      CASE WHEN i.item_type='inventory' THEN
        'sale:'||v_sale_id::text||':rule:'||(v_c.value->>'rule_id')
        ||':line:'||COALESCE(v_c.value->>'sale_line_id','order')
      ELSE NULL END,
      (i.item_type='inventory')
    FROM public.items i
    WHERE i.id=(v_c.value->>'consumed_item_id')::uuid
      AND i.restaurant_id=p_restaurant_id;
  END LOOP;

  RETURN jsonb_build_object('sale_id',v_sale_id,
    'invoice_number',v_invoice,'replayed',false,'contract_version',2);
END;
$$;

-- Strictly separate void: reversal reads original item ledger entries,
-- never current recipe or packaging rules.
CREATE OR REPLACE FUNCTION public.pos_void_sale_v2(
  p_restaurant_id uuid,
  p_device_id uuid,
  p_device_secret text,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
SET row_security = off
AS $$
DECLARE
  v_sale public.sales;
  v_void public.sale_voids;
  v_sale_id uuid;
  v_void_id uuid;
  v_op text;
  v_digest text;
  v_reason text;
  v_voided_at timestamptz;
  v_m public.item_ledger_entries;
BEGIN
  PERFORM public.assert_pos_device(
    p_restaurant_id,p_device_id,p_device_secret
  );

  IF p_payload IS NULL OR jsonb_typeof(p_payload)<>'object'
     OR COALESCE((p_payload->>'contract_version')::integer,0)<>2
  THEN RAISE EXCEPTION 'invalid_void_v2_payload' USING ERRCODE='22023'; END IF;

  v_sale_id:=NULLIF(p_payload->>'sale_id','')::uuid;
  v_void_id:=NULLIF(p_payload->>'void_id','')::uuid;
  v_op:=NULLIF(btrim(p_payload->>'operation_key'),'');
  v_reason:=NULLIF(btrim(p_payload->>'reason'),'');
  v_voided_at:=NULLIF(p_payload->>'voided_at','')::timestamptz;
  IF v_sale_id IS NULL OR v_void_id IS NULL OR v_op IS NULL
     OR v_reason IS NULL OR v_voided_at IS NULL THEN
    RAISE EXCEPTION 'incomplete_void_v2_identity' USING ERRCODE='22023';
  END IF;

  v_digest:=md5(p_payload::text);
  PERFORM pg_advisory_xact_lock(
    hashtext(p_restaurant_id::text),hashtext('void:'||v_op)
  );

  SELECT * INTO v_void
  FROM public.sale_voids
  WHERE restaurant_id=p_restaurant_id AND operation_key=v_op FOR UPDATE;
  IF v_void.id IS NOT NULL THEN
    IF v_void.id<>v_void_id OR v_void.sale_id<>v_sale_id
       OR v_void.operation_digest<>v_digest THEN
      RAISE EXCEPTION 'void_v2_idempotency_mismatch' USING ERRCODE='23514';
    END IF;
    RETURN jsonb_build_object('sale_id',v_sale_id,'void_id',v_void_id,
      'replayed',true,'contract_version',2);
  END IF;

  SELECT * INTO v_sale FROM public.sales
  WHERE restaurant_id=p_restaurant_id AND id=v_sale_id FOR UPDATE;
  IF v_sale.id IS NULL OR v_sale.sync_contract_version<>2
     OR v_sale.pos_device_id IS DISTINCT FROM p_device_id
  THEN
    RAISE EXCEPTION 'void_v2_sale_invalid_or_wrong_device'
      USING ERRCODE='23503';
  END IF;
  IF v_sale.status<>'completed' THEN
    RAISE EXCEPTION 'void_v2_sale_already_voided' USING ERRCODE='23514';
  END IF;

  IF auth.uid() IS NULL OR auth.uid() IS DISTINCT FROM v_sale.user_id THEN
    RAISE EXCEPTION 'void_v2_operator_not_authorized'
      USING ERRCODE='42501';
  END IF;

  -- Lock stock in deterministic item order; original values cannot change.
  FOR v_m IN SELECT * FROM public.item_ledger_entries e
    WHERE e.restaurant_id=p_restaurant_id
      AND e.source_type='sale' AND e.source_id=v_sale_id::text
      AND e.movement_type<>'reversal'
    ORDER BY e.item_id,e.id
  LOOP
    PERFORM item_core_internal.post_movement(
      'void:'||v_void_id::text||':movement:'||v_m.id,
      p_restaurant_id,v_m.item_id,'reversal',-v_m.quantity_delta,
      'sale_void',v_void_id::text,
      'void:'||v_op||':movement:'||v_m.id,
      v_m.unit_cost_base,v_m.id,p_device_id,auth.uid(),v_voided_at
    );
  END LOOP;

  INSERT INTO public.sale_voids(
    id,sale_id,restaurant_id,cash_register_session_id,
    voided_by_user_id,reason,original_total_amount,
    original_payment_method_id,original_payment_reference,
    sync_status,voided_at,operation_key,operation_digest
  ) VALUES(
    v_void_id,v_sale_id,p_restaurant_id,v_sale.cash_register_session_id,
    auth.uid(),v_reason,v_sale.total_amount,
    v_sale.payment_method_id,v_sale.payment_reference,
    'synced',v_voided_at,v_op,v_digest
  );

  UPDATE public.sales SET status='voided',updated_at=now()
  WHERE id=v_sale_id AND restaurant_id=p_restaurant_id;

  RETURN jsonb_build_object('sale_id',v_sale_id,'void_id',v_void_id,
    'replayed',false,'contract_version',2);
END;
$$;

REVOKE ALL ON FUNCTION public.pos_sync_sale_v2(uuid,uuid,text,jsonb),
  public.pos_void_sale_v2(uuid,uuid,text,jsonb)
  FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.pos_sync_sale_v2(uuid,uuid,text,jsonb),
  public.pos_void_sale_v2(uuid,uuid,text,jsonb) TO authenticated;
