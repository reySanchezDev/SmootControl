-- KIVO F2 - ATOMIC CANONICAL CONSUMPTION RULE MUTATION (DESIGN ONLY)
-- NOT A MIGRATION; do not run on active POS or primary PostgreSQL.
-- This RPC must replace EVERY direct item_consumption_rules writer at cutover.
-- New permission reglas_consumo.gestionar must be defined in the final
-- role-permission schema before this function is exposed to users.
-- Catalog revision MUST be locked BEFORE rule data changes.
CREATE OR REPLACE FUNCTION public.app_upsert_item_consumption_rule_v2(
  p_restaurant_id uuid,
  p_payload jsonb
) RETURNS public.item_consumption_rules
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=public,pg_temp
SET row_security=off
AS $$
DECLARE
  v_row public.item_consumption_rules;
  v_id uuid;
  v_source uuid;
  v_consumed uuid;
  v_sales_type uuid;
  v_unit uuid;
  v_scope text;
  v_quantity numeric;
  v_priority integer;
  v_revision bigint;
  v_is_active boolean;
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,'reglas_consumo.gestionar'
  );
  IF p_restaurant_id IS NULL OR p_payload IS NULL
     OR jsonb_typeof(p_payload)<>'object' THEN
    RAISE EXCEPTION 'invalid_consumption_rule_payload'
      USING ERRCODE='22023';
  END IF;

  v_id:=nullif(p_payload->>'id','')::uuid;
  v_source:=nullif(p_payload->>'source_item_id','')::uuid;
  v_consumed:=nullif(p_payload->>'consumed_item_id','')::uuid;
  v_sales_type:=nullif(p_payload->>'sales_type_id','')::uuid;
  v_unit:=nullif(p_payload->>'unit_id','')::uuid;
  v_scope:=p_payload->>'scope';
  v_quantity:=nullif(p_payload->>'quantity','')::numeric;
  v_priority:=nullif(p_payload->>'priority','')::integer;
  v_is_active:=nullif(p_payload->>'is_active','')::boolean;
  IF v_id IS NULL OR v_consumed IS NULL OR v_unit IS NULL
     OR v_scope NOT IN ('per_order','per_sale_line')
     OR v_scope IS NULL
     OR v_quantity IS NULL OR NOT isfinite(v_quantity)
     OR v_quantity<=0 OR round(v_quantity,6)<>v_quantity
     OR v_priority IS NULL OR v_is_active IS NULL
     OR (v_scope='per_sale_line' AND v_source IS NULL)
     OR v_source IS NOT DISTINCT FROM v_consumed THEN
    RAISE EXCEPTION 'invalid_consumption_rule_fields'
      USING ERRCODE='22023';
  END IF;

  SELECT revision INTO v_revision
  FROM public.item_catalog_revisions
  WHERE restaurant_id=p_restaurant_id FOR UPDATE;
  IF v_revision IS NULL THEN
    RAISE EXCEPTION 'consumption_catalog_revision_not_initialized'
      USING ERRCODE='23503';
  END IF;

  IF NOT EXISTS(
    SELECT 1 FROM public.items i
    WHERE i.id=v_consumed AND i.restaurant_id=p_restaurant_id
      AND i.is_active AND i.item_type IN ('inventory','non_inventory')
  ) OR NOT EXISTS(
    SELECT 1 FROM public.item_units u
    WHERE u.item_id=v_consumed AND u.restaurant_id=p_restaurant_id
      AND u.unit_id=v_unit AND u.is_active
  ) THEN
    RAISE EXCEPTION 'consumption_rule_invalid_target_or_unit'
      USING ERRCODE='23514';
  END IF;
  IF v_source IS NOT NULL AND NOT EXISTS(
    SELECT 1 FROM public.items i
    WHERE i.id=v_source AND i.restaurant_id=p_restaurant_id
      AND i.is_active AND i.can_sell
  ) THEN
    RAISE EXCEPTION 'consumption_rule_invalid_source'
      USING ERRCODE='23514';
  END IF;
  IF v_sales_type IS NOT NULL AND NOT EXISTS(
    SELECT 1 FROM public.sales_types s
    WHERE s.id=v_sales_type AND s.restaurant_id=p_restaurant_id
      AND s.is_active
  ) THEN
    RAISE EXCEPTION 'consumption_rule_invalid_sales_type'
      USING ERRCODE='23514';
  END IF;

  SELECT * INTO v_row FROM public.item_consumption_rules
  WHERE id=v_id AND restaurant_id=p_restaurant_id FOR UPDATE;

  -- Same payload is an idempotent no-op: no new catalog revision.
  IF v_row.id IS NOT NULL
     AND v_row.source_item_id IS NOT DISTINCT FROM v_source
     AND v_row.consumed_item_id=v_consumed
     AND v_row.sales_type_id IS NOT DISTINCT FROM v_sales_type
     AND v_row.unit_id=v_unit AND v_row.scope=v_scope
     AND v_row.quantity=v_quantity AND v_row.priority=v_priority
     AND v_row.is_active=v_is_active THEN
    RETURN v_row;
  END IF;

  -- Equal-specificity duplicate rules would make the POS resolver fail.
  IF v_is_active AND EXISTS(
    SELECT 1 FROM public.item_consumption_rules r
    WHERE r.restaurant_id=p_restaurant_id AND r.id<>v_id
      AND r.is_active AND r.scope=v_scope
      AND r.source_item_id IS NOT DISTINCT FROM v_source
      AND r.consumed_item_id=v_consumed
      AND r.sales_type_id IS NOT DISTINCT FROM v_sales_type
      AND r.priority=v_priority
  ) THEN
    RAISE EXCEPTION 'duplicate_consumption_rule_rank'
      USING ERRCODE='23514';
  END IF;

  IF v_row.id IS NULL THEN
    IF EXISTS(SELECT 1 FROM public.item_consumption_rules WHERE id=v_id) THEN
      RAISE EXCEPTION 'consumption_rule_cross_tenant_id_collision'
        USING ERRCODE='23505';
    END IF;
    INSERT INTO public.item_consumption_rules(
      id,restaurant_id,source_item_id,consumed_item_id,
      sales_type_id,scope,quantity,unit_id,priority,is_active
    ) VALUES(
      v_id,p_restaurant_id,v_source,v_consumed,
      v_sales_type,v_scope,v_quantity,v_unit,v_priority,v_is_active
    ) RETURNING * INTO v_row;
  ELSE
    UPDATE public.item_consumption_rules SET
      source_item_id=v_source,consumed_item_id=v_consumed,
      sales_type_id=v_sales_type,scope=v_scope,quantity=v_quantity,
      unit_id=v_unit,priority=v_priority,is_active=v_is_active,
      updated_at=now()
    WHERE id=v_id AND restaurant_id=p_restaurant_id
    RETURNING * INTO v_row;
  END IF;

  PERFORM item_core_internal.bump_item_catalog_revision(p_restaurant_id);
  RETURN v_row;
END;
$$;

REVOKE ALL ON public.item_consumption_rules
  FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.item_consumption_rules TO authenticated;
REVOKE ALL ON FUNCTION public.app_upsert_item_consumption_rule_v2(uuid,jsonb)
  FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.app_upsert_item_consumption_rule_v2(uuid,jsonb)
  TO authenticated;

-- Still required G2: adapt all direct Rule CRUD/editor routes, forbid other
-- RPCs writing item_consumption_rules, use real tenant permissions/JWT,
-- and test the complete resolver, sales/void and offline cutover together.
