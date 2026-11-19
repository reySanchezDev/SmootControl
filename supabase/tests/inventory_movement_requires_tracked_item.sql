BEGIN;
DO $$
DECLARE
  v_restaurant uuid;
  v_item uuid;
  v_actor uuid;
  v_error text;
BEGIN
  SELECT item.restaurant_id, item.id, profile.id
    INTO v_restaurant, v_item, v_actor
  FROM public.items item
  JOIN public.profiles profile
    ON profile.restaurant_id = item.restaurant_id AND profile.is_active
  WHERE NOT item.tracks_inventory
  LIMIT 1;
  IF v_item IS NULL THEN
    RAISE EXCEPTION 'fixture_non_inventory_item_missing';
  END IF;
  PERFORM set_config('request.jwt.claim.sub', v_actor::text, true);
  BEGIN
    PERFORM public.apply_inventory_movement_v2(
      'audit-nontracked-' || v_item::text, v_restaurant, v_item, NULL,
      'adjustment', 1, 'audit', NULL, v_actor::text, 'rolled-back audit', now(), 0
    );
    RAISE EXCEPTION 'nontracked_movement_was_accepted';
  EXCEPTION WHEN check_violation THEN
    GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
    IF v_error <> 'item_inventory_tracking_required' THEN RAISE; END IF;
  END;
  IF EXISTS (
    SELECT 1 FROM public.inventory_movements
    WHERE id = 'audit-nontracked-' || v_item::text
  ) THEN
    RAISE EXCEPTION 'nontracked_movement_was_persisted';
  END IF;
END;
$$;
ROLLBACK;
