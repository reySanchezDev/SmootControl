-- KIVO F2.3 - CANONICAL ITEM UNIT REVISION WRITER (DESIGN ONLY)
-- Not a migration; never run against operating PostgreSQL.
-- The coordinated cutover must remove ALL alternative item_units writers.
CREATE OR REPLACE FUNCTION public.app_upsert_item_unit_v2(
  p_restaurant_id uuid,
  p_item_id uuid,
  p_unit_id uuid,
  p_quantity_in_base numeric,
  p_is_purchase boolean,
  p_is_sale boolean,
  p_is_active boolean
) RETURNS public.item_units
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=public,pg_temp
SET row_security=off
AS $$
DECLARE
  v_revision bigint;
  v_base_unit_id uuid;
  v_existing public.item_units;
  v_result public.item_units;
BEGIN
  IF p_restaurant_id IS NULL OR p_item_id IS NULL OR p_unit_id IS NULL
     OR NOT public.app_item_has_write_access(
       p_restaurant_id,'articulos.gestionar'
     ) THEN
    RAISE EXCEPTION 'item_unit_write_not_authorized' USING ERRCODE='42501';
  END IF;
  IF p_quantity_in_base IS NULL
     OR p_quantity_in_base::text IN ('NaN','Infinity','-Infinity')
     OR p_quantity_in_base<=0 OR round(p_quantity_in_base,8)<>p_quantity_in_base
     OR p_quantity_in_base>9999999999
     OR p_is_purchase IS NULL OR p_is_sale IS NULL OR p_is_active IS NULL THEN
    RAISE EXCEPTION 'invalid_item_unit_fields' USING ERRCODE='22023';
  END IF;

  -- The catalog lock must precede EVERY catalog mutation, including units.
  SELECT revision INTO v_revision FROM public.item_catalog_revisions
  WHERE restaurant_id=p_restaurant_id FOR UPDATE;
  IF v_revision IS NULL THEN
    RAISE EXCEPTION 'item_catalog_revision_not_initialized'
      USING ERRCODE='23503';
  END IF;

  SELECT base_unit_id INTO v_base_unit_id FROM public.items
  WHERE restaurant_id=p_restaurant_id AND id=p_item_id FOR UPDATE;
  IF v_base_unit_id IS NULL THEN
    RAISE EXCEPTION 'item_unit_item_missing' USING ERRCODE='23503';
  END IF;
  IF NOT EXISTS(
    SELECT 1 FROM public.measurement_units target
    JOIN public.measurement_units base
      ON base.id=v_base_unit_id
    WHERE target.id=p_unit_id AND target.is_active AND base.is_active
      AND target.unit_group=base.unit_group
      AND (target.restaurant_id IS NULL
           OR target.restaurant_id=p_restaurant_id)
      AND (base.restaurant_id IS NULL
           OR base.restaurant_id=p_restaurant_id)
  ) THEN
    RAISE EXCEPTION 'item_unit_invalid_dimension_or_tenant'
      USING ERRCODE='23514';
  END IF;
  IF p_unit_id=v_base_unit_id
     AND (p_quantity_in_base<>1 OR NOT p_is_active) THEN
    RAISE EXCEPTION 'item_unit_base_must_be_active_one'
      USING ERRCODE='23514';
  END IF;

  SELECT * INTO v_existing FROM public.item_units
  WHERE restaurant_id=p_restaurant_id
    AND item_id=p_item_id AND unit_id=p_unit_id FOR UPDATE;
  IF v_existing.item_id IS NOT NULL
     AND v_existing.quantity_in_base=p_quantity_in_base
     AND v_existing.is_purchase=p_is_purchase
     AND v_existing.is_sale=p_is_sale
     AND v_existing.is_active=p_is_active THEN
    RETURN v_existing;
  END IF;

  -- Active rules must not reference a removed/disabled conversion.
  IF NOT p_is_active AND EXISTS(
    SELECT 1 FROM public.item_consumption_rules r
    WHERE r.restaurant_id=p_restaurant_id AND r.is_active
      AND r.consumed_item_id=p_item_id AND r.unit_id=p_unit_id
  ) THEN
    RAISE EXCEPTION 'item_unit_referenced_by_consumption_rule'
      USING ERRCODE='23514';
  END IF;
  IF p_is_active AND p_is_purchase AND EXISTS(
    SELECT 1 FROM public.item_units u
    WHERE u.restaurant_id=p_restaurant_id AND u.item_id=p_item_id
      AND u.unit_id<>p_unit_id AND u.is_active AND u.is_purchase
  ) THEN
    RAISE EXCEPTION 'item_unit_purchase_already_assigned'
      USING ERRCODE='23505';
  END IF;
  IF p_is_active AND p_is_sale AND EXISTS(
    SELECT 1 FROM public.item_units u
    WHERE u.restaurant_id=p_restaurant_id AND u.item_id=p_item_id
      AND u.unit_id<>p_unit_id AND u.is_active AND u.is_sale
  ) THEN
    RAISE EXCEPTION 'item_unit_sale_already_assigned'
      USING ERRCODE='23505';
  END IF;

  INSERT INTO public.item_units(
    restaurant_id,item_id,unit_id,quantity_in_base,
    is_purchase,is_sale,is_active
  ) VALUES(
    p_restaurant_id,p_item_id,p_unit_id,p_quantity_in_base,
    p_is_purchase,p_is_sale,p_is_active
  ) ON CONFLICT(restaurant_id,item_id,unit_id) DO UPDATE SET
    quantity_in_base=EXCLUDED.quantity_in_base,
    is_purchase=EXCLUDED.is_purchase,
    is_sale=EXCLUDED.is_sale,
    is_active=EXCLUDED.is_active
  RETURNING * INTO v_result;

  PERFORM item_core_internal.bump_item_catalog_revision(p_restaurant_id);
  RETURN v_result;
END;
$$;

REVOKE ALL ON public.item_units FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.item_units TO authenticated;
REVOKE ALL ON FUNCTION public.app_upsert_item_unit_v2(
  uuid,uuid,uuid,numeric,boolean,boolean,boolean
) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.app_upsert_item_unit_v2(
  uuid,uuid,uuid,numeric,boolean,boolean,boolean
) TO authenticated;

-- G2 remains blocked on real JWT/RLS, remaining classification/category
-- writers, complete DTO, Drift transaction, old writer retirement and cutover.
