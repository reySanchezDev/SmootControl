-- Separate product-master authority from packaging-rule authority.
-- 092 granted both capabilities through one guard; least-privilege correction.
-- 088 stays frozen. No data migration or destructive operation.
BEGIN;
CREATE OR REPLACE FUNCTION item_core_internal.assert_catalog_write(
  p_restaurant_id uuid
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1
    FROM public.profiles actor
    JOIN public.role_permissions grant_row ON grant_row.role_id = actor.role_id
    JOIN public.permissions permission ON permission.id = grant_row.permission_id
    WHERE actor.id = auth.uid()
      AND actor.restaurant_id = p_restaurant_id
      AND actor.is_active = true
      AND actor.is_pos_user = false
      AND permission.code IN (
        'productos.gestionar'
      )
  ) THEN
    RAISE EXCEPTION 'item_catalog_write_not_authorized' USING ERRCODE = '42501';
  END IF;
END;
$$;


REVOKE ALL ON FUNCTION item_core_internal.assert_catalog_write(uuid)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION item_core_internal.assert_packaging_write(
  p_restaurant_id uuid
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1
    FROM public.profiles actor
    JOIN public.role_permissions grant_row ON grant_row.role_id = actor.role_id
    JOIN public.permissions permission ON permission.id = grant_row.permission_id
    WHERE actor.id = auth.uid()
      AND actor.restaurant_id = p_restaurant_id
      AND actor.is_active = true
      AND actor.is_pos_user = false
      AND permission.code = 'empaques.gestionar'
  ) THEN
    RAISE EXCEPTION 'packaging_write_not_authorized' USING ERRCODE='42501';
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION item_core_internal.assert_packaging_write(uuid)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.app_upsert_item_consumption_rule_v2(
  p_restaurant_id uuid, p_payload jsonb
) RETURNS public.item_consumption_rules LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE v_row public.item_consumption_rules;
BEGIN
  PERFORM item_core_internal.assert_packaging_write(p_restaurant_id);
  INSERT INTO public.item_consumption_rules(
    id, restaurant_id, source_item_id, consumed_item_id, sales_type_id, scope,
    quantity, unit_id, priority, is_active, updated_at
  ) VALUES (
    COALESCE((p_payload->>'id')::uuid, gen_random_uuid()), p_restaurant_id,
    (p_payload->>'source_item_id')::uuid, (p_payload->>'consumed_item_id')::uuid,
    (p_payload->>'sales_type_id')::uuid, p_payload->>'scope',
    (p_payload->>'quantity')::numeric, (p_payload->>'unit_id')::uuid,
    COALESCE((p_payload->>'priority')::integer, 100),
    COALESCE((p_payload->>'is_active')::boolean, true), now()
  ) ON CONFLICT (id) DO UPDATE SET source_item_id=EXCLUDED.source_item_id,
    consumed_item_id=EXCLUDED.consumed_item_id, sales_type_id=EXCLUDED.sales_type_id,
    scope=EXCLUDED.scope, quantity=EXCLUDED.quantity, unit_id=EXCLUDED.unit_id,
    priority=EXCLUDED.priority, is_active=EXCLUDED.is_active, updated_at=now()
  WHERE item_consumption_rules.restaurant_id=p_restaurant_id
  RETURNING * INTO v_row;
  PERFORM item_core_internal.bump_item_catalog_revision(p_restaurant_id);
  RETURN v_row;
END;
$$;

REVOKE ALL ON FUNCTION public.app_upsert_item_consumption_rule_v2(uuid,jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_upsert_item_consumption_rule_v2(uuid,jsonb)
  TO authenticated;
COMMIT;
