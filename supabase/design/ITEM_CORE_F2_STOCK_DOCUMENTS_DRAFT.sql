-- KIVO F2 - PURCHASE / ADJUSTMENT BUSINESS TRANSACTIONS - DESIGN ONLY
-- DO NOT MOVE TO supabase/migrations; DO NOT RUN ON OPERATING DATABASE.
-- Prerequisite: F1 items, item_units, and F2 private post_movement engine.
-- No legacy products/packaging stock writers are used.
-- All lines in one PostgreSQL transaction; idempotence at DOCUMENT level.
-- This prototype supports BASE unit counts for adjustments and exactly
-- one selected purchase unit per item. No suppliers/taxes/multi-currency.
-- These advanced scenarios must be integrated before POS/ERP cutover.

CREATE TABLE public.item_inventory_operations (
  id uuid PRIMARY KEY,
  restaurant_id uuid NOT NULL,
  operation_key text NOT NULL CHECK(length(btrim(operation_key)) > 0),
  operation_type text NOT NULL CHECK(
    operation_type IN ('purchase','adjustment')
  ),
  payload_digest text NOT NULL CHECK(length(payload_digest) > 0),
  actor_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(restaurant_id, operation_key)
);

ALTER TABLE public.item_inventory_operations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.item_inventory_operations FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.item_inventory_operations TO authenticated;
CREATE POLICY item_inventory_operations_read ON public.item_inventory_operations
  FOR SELECT TO authenticated
  USING(restaurant_id = public.current_restaurant_id());

CREATE OR REPLACE FUNCTION public.app_post_item_stock_document_v2(
  p_restaurant_id uuid,
  p_document_id uuid,
  p_operation_key text,
  p_document_type text,
  p_lines jsonb,
  p_occurred_at timestamptz
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
SET row_security = off
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_digest text;
  v_prior public.item_inventory_operations;
  v_row jsonb;
  v_item public.items;
  v_unit public.item_units;
  v_item_id uuid;
  v_unit_id uuid;
  v_quantity numeric;
  v_base_quantity numeric;
  v_cost numeric;
  v_current numeric;
  v_expected numeric;
  v_delta numeric;
  v_index integer := 0;
  v_posted integer := 0;
BEGIN
  IF v_actor IS NULL
     OR NOT public.app_item_has_write_access(
       p_restaurant_id, 'inventario.gestionar'
     ) THEN
    RAISE EXCEPTION 'stock_document_not_authorized'
      USING ERRCODE='42501';
  END IF;

  IF p_restaurant_id IS NULL OR p_document_id IS NULL
     OR p_operation_key IS NULL OR length(btrim(p_operation_key))=0
     OR p_document_type NOT IN ('purchase','adjustment')
     OR p_occurred_at IS NULL
     OR p_lines IS NULL OR jsonb_typeof(p_lines)<>'array'
     OR jsonb_array_length(p_lines)=0 THEN
    RAISE EXCEPTION 'invalid_stock_document'
      USING ERRCODE='22023';
  END IF;

  v_digest := md5(jsonb_build_object(
    'restaurant',p_restaurant_id,'id',p_document_id,
    'operation_key',p_operation_key,'type',p_document_type,
    'lines',p_lines,'occurred_at',p_occurred_at
  )::text);

  PERFORM pg_advisory_xact_lock(
    hashtext(p_restaurant_id::text),
    hashtext('stock:'||p_operation_key)
  );

  SELECT * INTO v_prior FROM public.item_inventory_operations
  WHERE restaurant_id=p_restaurant_id AND operation_key=p_operation_key
  FOR UPDATE;
  IF v_prior.id IS NOT NULL THEN
    IF v_prior.id <> p_document_id
       OR v_prior.operation_type <> p_document_type
       OR v_prior.payload_digest <> v_digest THEN
      RAISE EXCEPTION 'stock_document_idempotency_mismatch'
        USING ERRCODE='23514';
    END IF;
    RETURN jsonb_build_object('document_id',p_document_id,
      'posted',false,'replayed',true,'contract_version',2);
  END IF;

  IF EXISTS(
    SELECT 1 FROM public.item_inventory_operations
    WHERE id=p_document_id
  ) THEN
    RAISE EXCEPTION 'stock_document_id_collision'
      USING ERRCODE='23505';
  END IF;

  -- Canonicalize each unique item once. Duplicate item rows have no
  -- ambiguous count/cost semantics and must be rejected explicitly.
  IF EXISTS(
    SELECT 1 FROM jsonb_array_elements(p_lines) l
    GROUP BY l->>'item_id' HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'duplicate_stock_document_item'
      USING ERRCODE='23514';
  END IF;

  -- Insert header BEFORE movements: PostgreSQL rolls it back if any
  -- validation or movement fails, guaranteeing document-level atomicity.
  INSERT INTO public.item_inventory_operations(
    id,restaurant_id,operation_key,operation_type,payload_digest,actor_id
  ) VALUES(
    p_document_id,p_restaurant_id,p_operation_key,p_document_type,
    v_digest,v_actor
  );

  -- Deterministic item lock order minimizes deadlocks across documents.
  FOR v_row IN
    SELECT value FROM jsonb_array_elements(p_lines)
    ORDER BY value->>'item_id'
  LOOP
    v_index := v_index + 1;
    IF jsonb_typeof(v_row)<>'object' THEN
      RAISE EXCEPTION 'invalid_stock_document_line'
        USING ERRCODE='22023';
    END IF;
    v_item_id := nullif(v_row->>'item_id','')::uuid;
    v_unit_id := nullif(v_row->>'unit_id','')::uuid;
    v_quantity := nullif(v_row->>'quantity','')::numeric;
    IF v_item_id IS NULL OR v_unit_id IS NULL OR
       v_quantity IS NULL OR v_quantity < 0 THEN
      RAISE EXCEPTION 'invalid_stock_document_quantity'
        USING ERRCODE='22023';
    END IF;

    SELECT * INTO v_item FROM public.items
    WHERE id=v_item_id AND restaurant_id=p_restaurant_id
    FOR SHARE;
    IF v_item.id IS NULL OR NOT v_item.is_active
       OR v_item.item_type <> 'inventory' THEN
      RAISE EXCEPTION 'stock_document_requires_inventory_item'
        USING ERRCODE='23514';
    END IF;

    SELECT * INTO v_unit FROM public.item_units
    WHERE restaurant_id=p_restaurant_id AND item_id=v_item_id
      AND unit_id=v_unit_id AND is_active
    FOR SHARE;
    IF v_unit.item_id IS NULL OR v_unit.quantity_in_base<=0 THEN
      RAISE EXCEPTION 'stock_document_invalid_item_unit'
        USING ERRCODE='23514';
    END IF;

    IF p_document_type='purchase' THEN
      IF NOT v_item.can_purchase OR NOT v_unit.is_purchase
         OR v_quantity<=0 THEN
        RAISE EXCEPTION 'stock_document_item_not_purchasable'
          USING ERRCODE='23514';
      END IF;
      v_cost := nullif(v_row->>'unit_cost','')::numeric;
      IF v_cost IS NULL OR v_cost<0 THEN
        RAISE EXCEPTION 'stock_document_invalid_purchase_cost'
          USING ERRCODE='22023';
      END IF;
      v_base_quantity := v_quantity*v_unit.quantity_in_base;
      IF round(v_base_quantity,6) <> v_base_quantity THEN
        RAISE EXCEPTION 'stock_document_precision_loss'
          USING ERRCODE='23514';
      END IF;
      v_delta := v_base_quantity;
      -- Cost provided is PER SELECTED PURCHASE UNIT.
      v_cost := round(v_cost/v_unit.quantity_in_base,6);
    ELSE
      IF v_unit_id <> v_item.base_unit_id THEN
        RAISE EXCEPTION 'adjustment_requires_base_unit'
          USING ERRCODE='23514';
      END IF;
      v_expected := nullif(v_row->>'expected_stock','')::numeric;
      IF v_expected IS NULL OR v_expected<0 THEN
        RAISE EXCEPTION 'adjustment_expected_stock_missing'
          USING ERRCODE='22023';
      END IF;
      -- Serialize the optimistic count against purchases/other adjustments.
      -- Holding this lock until commit prevents a TOCTOU between expected
      -- stock and the internal ledger update.
      INSERT INTO public.item_stock(restaurant_id,item_id)
      VALUES(p_restaurant_id,v_item_id) ON CONFLICT DO NOTHING;
      SELECT quantity_on_hand INTO v_current
      FROM public.item_stock
      WHERE restaurant_id=p_restaurant_id AND item_id=v_item_id
      FOR UPDATE;
      v_current := COALESCE(v_current,0);
      IF v_current <> v_expected THEN
        RAISE EXCEPTION 'adjustment_stock_changed'
          USING ERRCODE='40001';
      END IF;
      v_delta := v_quantity-v_current;
      v_cost := v_item.base_unit_cost;
    END IF;

    IF v_delta<>0 THEN
      PERFORM item_core_internal.post_movement(
        'stockdoc:'||p_document_id::text||':'||v_item_id::text,
        p_restaurant_id,v_item_id,
        CASE WHEN p_document_type='purchase' THEN 'purchase'
          ELSE 'adjustment' END,
        v_delta,'stock_document',p_document_id::text,
        'stockdoc:'||p_operation_key||':'||v_item_id::text,
        v_cost,NULL,NULL,v_actor,p_occurred_at
      );
      v_posted := v_posted+1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('document_id',p_document_id,
    'posted',true,'posted_lines',v_posted,'replayed',false,
    'contract_version',2);
END;
$$;

REVOKE ALL ON FUNCTION public.app_post_item_stock_document_v2(
  uuid,uuid,text,text,jsonb,timestamptz
) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.app_post_item_stock_document_v2(
  uuid,uuid,text,text,jsonb,timestamptz
) TO authenticated;

-- The operation table is immutable by client grants. A future hardened
-- migration must bind owner/privileges and test direct REST + RLS.
