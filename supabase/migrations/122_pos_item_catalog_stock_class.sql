-- Includes business class and canonical item stock in the POS snapshot.
BEGIN;

CREATE OR REPLACE FUNCTION public.pos_pull_item_catalog_v2(
  p_restaurant_id uuid,
  p_device_id uuid,
  p_device_secret text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_revision bigint;
  v_snapshot_id uuid;
BEGIN
  PERFORM public.assert_pos_device(
    p_restaurant_id, p_device_id, p_device_secret
  );
  SELECT revision, snapshot_id INTO v_revision, v_snapshot_id
  FROM public.item_catalog_revisions
  WHERE restaurant_id = p_restaurant_id FOR SHARE;
  IF v_revision IS NULL THEN
    RAISE EXCEPTION 'catalog_revision_not_initialized';
  END IF;
  RETURN jsonb_build_object(
    'contract_version', 2,
    'restaurant_id', p_restaurant_id,
    'snapshot_complete', true,
    'snapshot_id', v_snapshot_id,
    'revision', v_revision,
    'items', COALESCE((
      SELECT jsonb_agg(
        to_jsonb(i) || jsonb_build_object(
          'quantity_on_hand', COALESCE(s.quantity_on_hand, 0)
        ) ORDER BY i.code, i.id
      )
      FROM public.items i
      LEFT JOIN public.inventory_stock s
        ON s.restaurant_id = i.restaurant_id AND s.item_id = i.id
      WHERE i.restaurant_id = p_restaurant_id
    ), '[]'::jsonb),
    'item_units', COALESCE((
      SELECT jsonb_agg(to_jsonb(u) ORDER BY u.item_id, u.unit_id)
      FROM public.item_units u
      WHERE u.restaurant_id = p_restaurant_id AND u.is_active
    ), '[]'::jsonb),
    'item_classifications', COALESCE((
      SELECT jsonb_agg(to_jsonb(c) ORDER BY c.code, c.id)
      FROM public.item_classifications c
      WHERE c.restaurant_id = p_restaurant_id
    ), '[]'::jsonb),
    'item_classification_links', COALESCE((
      SELECT jsonb_agg(to_jsonb(l) ORDER BY l.item_id, l.classification_id)
      FROM public.item_classification_links l
      WHERE l.restaurant_id = p_restaurant_id
    ), '[]'::jsonb),
    'consumption_rules', COALESCE((
      SELECT jsonb_agg(to_jsonb(r) ORDER BY r.id)
      FROM public.item_consumption_rules r
      WHERE r.restaurant_id = p_restaurant_id AND r.is_active
    ), '[]'::jsonb)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.pos_pull_item_catalog_v2(uuid, uuid, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pos_pull_item_catalog_v2(uuid, uuid, text)
  TO authenticated;

COMMIT;
