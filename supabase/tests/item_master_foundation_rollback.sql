-- Run ONLY against local Docker database AFTER migration 088.
-- Test data is rolled back even on successful assertions. psql -v ON_ERROR_STOP=1.
BEGIN;

DO $$
DECLARE
  tenant_a uuid := gen_random_uuid();
  tenant_b uuid := gen_random_uuid();
  cat_a uuid := gen_random_uuid();
  cat_b uuid := gen_random_uuid();
  product_a uuid := gen_random_uuid();
  packaging_a uuid := gen_random_uuid();
  service_a uuid := gen_random_uuid();
  actual_count integer;
  current_name text;
BEGIN
  INSERT INTO public.restaurants(id, commercial_name)
  VALUES (tenant_a, 'Item foundation temporary A'),
         (tenant_b, 'Item foundation temporary B');
  INSERT INTO public.product_categories(id, restaurant_id, name)
  VALUES (cat_a, tenant_a, 'Temporary category'),
         (cat_b, tenant_b, 'Temporary other tenant');

  INSERT INTO public.products (
    id, restaurant_id, category_id, code, name, cost, price,
    is_raw_material, tracks_inventory
  ) VALUES (
    product_a, tenant_a, cat_a, 'TEST-' || product_a::text,
    'Temporary product', 2, 5, false, true
  );

  INSERT INTO public.packaging_items(
    id, restaurant_id, name, cost, tracks_stock
  ) VALUES (
    packaging_a, tenant_a, 'Temporary packaging', 1, true
  );

  SELECT count(*) INTO actual_count
  FROM public.items
  WHERE restaurant_id = tenant_a AND id IN (product_a, packaging_a);
  IF actual_count <> 2 THEN
    RAISE EXCEPTION 'Mirror insert failed, expected 2 got %', actual_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.items
    WHERE id = product_a AND source_kind = 'product'
      AND item_type = 'inventory'
      AND item_class = 'sale_product'
      AND is_sellable = true AND tracks_inventory = true
  ) THEN RAISE EXCEPTION 'Product master mapping incorrect'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.items
    WHERE id = packaging_a AND source_kind = 'packaging'
      AND item_type = 'inventory'
      AND item_class = 'packaging'
      AND is_sellable = false AND tracks_inventory = true
  ) THEN RAISE EXCEPTION 'Packaging master mapping incorrect'; END IF;

  UPDATE public.packaging_items
  SET name = 'Temporary packaging edited', tracks_stock = false
  WHERE id = packaging_a;

  SELECT name INTO current_name FROM public.items WHERE id = packaging_a;
  IF current_name <> 'Temporary packaging edited'
     OR NOT EXISTS (
       SELECT 1 FROM public.items
       WHERE id = packaging_a AND item_type = 'non_inventory'
         AND tracks_inventory = false
     ) THEN
    RAISE EXCEPTION 'Packaging mirror update failed';
  END IF;

  UPDATE public.products
  SET is_raw_material = true, is_available_in_pos = false
  WHERE id = product_a;

  IF NOT EXISTS (
    SELECT 1 FROM public.items
    WHERE id = product_a AND item_class = 'raw_material'
      AND NOT is_sellable
  ) THEN RAISE EXCEPTION 'Raw material mapping failed'; END IF;

  INSERT INTO public.items (
    id, restaurant_id, code, name, item_type, item_class,
    source_kind, unit_cost, unit_price, is_sellable
  ) VALUES (
    service_a, tenant_a, 'SRV-' || service_a::text,
    'Temporary service', 'service', 'service', 'native', 0, 100, true
  );

  UPDATE public.items SET name = 'Temporary service edited'
  WHERE id = service_a;

  IF NOT EXISTS (
    SELECT 1 FROM public.items WHERE id = service_a
      AND name = 'Temporary service edited'
      AND item_type = 'service' AND source_kind = 'native'
  ) THEN RAISE EXCEPTION 'Native service insert/update failed'; END IF;

  -- Reject other tenant's category regardless of the caller.
  BEGIN
    UPDATE public.items SET category_id = cat_b WHERE id = service_a;
    RAISE EXCEPTION 'Expected cross-tenant category rejection';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;

  -- Reject an inventory ledger flag on a non-inventory service.
  BEGIN
    UPDATE public.items SET tracks_inventory = true WHERE id = service_a;
    RAISE EXCEPTION 'Expected service inventory rule rejection';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;

  -- Existing rows have an actual canonical master record. No identity rekey.
  IF EXISTS (
    SELECT 1 FROM public.products p
    LEFT JOIN public.items i ON i.id = p.id
    WHERE i.id IS NULL OR i.source_kind <> 'product'
      OR p.restaurant_id <> i.restaurant_id
  ) THEN RAISE EXCEPTION 'Unmapped product'; END IF;

  IF EXISTS (
    SELECT 1 FROM public.packaging_items k
    LEFT JOIN public.items i ON i.id = k.id
    WHERE i.id IS NULL OR i.source_kind <> 'packaging'
      OR k.restaurant_id <> i.restaurant_id
  ) THEN RAISE EXCEPTION 'Unmapped packaging'; END IF;

  -- Old UUIDs are preserved by both source and master.
  RAISE NOTICE 'Item master foundation rollback tests passed';
END;
$$;

ROLLBACK;
