-- Run against the local Supabase lab after migrations. All fixture changes roll back.
BEGIN;
DO $test$
DECLARE
  v_restaurant uuid;
  v_actor uuid;
  v_payment uuid;
  v_sold_item uuid;
  v_raw_item uuid;
  v_product_item uuid;
  v_packaging_item uuid;
  v_sales uuid[] := ARRAY[gen_random_uuid(), gen_random_uuid()];
  v_sale_off uuid := gen_random_uuid();
  v_result jsonb;
  v_balance numeric;
  v_index integer;
BEGIN
  IF position('pos_apply_recipe_inventory_movements' IN pg_get_functiondef(
       'public.pos_sync_sale_v2(uuid,uuid,text,jsonb)'::regprocedure
     )) = 0 OR
     position('pos_reverse_recipe_inventory_movements' IN pg_get_functiondef(
       'public.pos_sync_sale_v2(uuid,uuid,text,jsonb)'::regprocedure
     )) = 0 THEN
    RAISE EXCEPTION 'canonical_pos_recipe_hooks_missing';
  END IF;

  SELECT recipe.restaurant_id, recipe.item_id, line.component_item_id
    INTO v_restaurant, v_sold_item, v_raw_item
  FROM public.item_recipes recipe
  JOIN public.items sold ON sold.id=recipe.item_id
    AND sold.restaurant_id=recipe.restaurant_id AND sold.uses_recipe
  JOIN public.item_recipe_lines line ON line.recipe_id=recipe.id
    AND line.restaurant_id=recipe.restaurant_id AND line.is_active
  JOIN public.items raw ON raw.id=line.component_item_id
    AND raw.restaurant_id=line.restaurant_id
    AND raw.item_class='raw_material' AND raw.tracks_inventory
  WHERE recipe.status='active' LIMIT 1;
  IF v_sold_item IS NULL THEN RAISE EXCEPTION 'recipe_fixture_missing'; END IF;

  SELECT id INTO v_actor FROM public.profiles
  WHERE restaurant_id=v_restaurant AND is_active LIMIT 1;
  SELECT id INTO v_payment FROM public.payment_methods
  WHERE restaurant_id=v_restaurant AND is_active LIMIT 1;
  SELECT id INTO v_product_item FROM public.items
  WHERE restaurant_id=v_restaurant AND item_class='sale_product'
    AND tracks_inventory LIMIT 1;
  SELECT id INTO v_packaging_item FROM public.items
  WHERE restaurant_id=v_restaurant AND item_class='packaging'
    AND tracks_inventory LIMIT 1;
  IF v_actor IS NULL OR v_payment IS NULL OR v_product_item IS NULL
     OR v_packaging_item IS NULL THEN
    RAISE EXCEPTION 'negative_stock_test_fixture_incomplete';
  END IF;
  PERFORM set_config('request.jwt.claim.sub',v_actor::text,true);

  INSERT INTO public.business_rules(restaurant_id,key,bool_value)
  VALUES(v_restaurant,'allow_raw_material_negative_stock_from_recipes',true)
  ON CONFLICT(restaurant_id,key) DO UPDATE SET bool_value=true;
  FOR v_index IN 1..2 LOOP
    INSERT INTO public.sales(id,restaurant_id,user_id,payment_method_id,
      invoice_number,total_amount,total_cost,gross_profit)
    VALUES(v_sales[v_index],v_restaurant,v_actor,v_payment,
      'RULE-ON-'||v_sales[v_index]::text,1,0,1);
    INSERT INTO public.sale_items(sale_id,item_id,product_code,product_name,
      category_name,quantity,unit_price,unit_cost,subtotal,gross_profit)
    VALUES(v_sales[v_index],v_sold_item,'RULE-RECIPE','QA recipe','QA',1,1,0,1,1);
  END LOOP;
  INSERT INTO public.inventory_stock(restaurant_id,item_id,quantity_on_hand)
  VALUES(v_restaurant,v_raw_item,0)
  ON CONFLICT(restaurant_id,item_id) DO UPDATE SET quantity_on_hand=0;
  PERFORM public.pos_apply_recipe_inventory_movements(v_restaurant,v_sales[1],'sale');
  PERFORM public.pos_apply_recipe_inventory_movements(v_restaurant,v_sales[2],'sale');
  SELECT quantity_on_hand INTO v_balance FROM public.inventory_stock
  WHERE restaurant_id=v_restaurant AND item_id=v_raw_item;
  IF v_balance >= 0 THEN RAISE EXCEPTION 'enabled_rule_did_not_allow_raw_negative'; END IF;
  v_result:=public.pos_apply_recipe_inventory_movements(v_restaurant,v_sales[1],'sale');
  IF (v_result->>'inserted_movements')::int<>0 THEN
    RAISE EXCEPTION 'recipe_retry_not_idempotent';
  END IF;

  UPDATE public.business_rules SET bool_value=false
  WHERE restaurant_id=v_restaurant
    AND key='allow_raw_material_negative_stock_from_recipes';
  v_result:=public.pos_reverse_recipe_inventory_movements(v_restaurant,v_sales[1]);
  SELECT quantity_on_hand INTO v_balance FROM public.inventory_stock
  WHERE restaurant_id=v_restaurant AND item_id=v_raw_item;
  IF v_balance >= 0 OR (v_result->>'inserted_movements')::int<1 THEN
    RAISE EXCEPTION 'recipe_void_did_not_restore_original_movement';
  END IF;
  v_result:=public.pos_reverse_recipe_inventory_movements(v_restaurant,v_sales[1]);
  IF (v_result->>'inserted_movements')::int<>0 THEN
    RAISE EXCEPTION 'recipe_void_retry_not_idempotent';
  END IF;

  INSERT INTO public.sales(id,restaurant_id,user_id,payment_method_id,
    invoice_number,total_amount,total_cost,gross_profit)
  VALUES(v_sale_off,v_restaurant,v_actor,v_payment,
    'RULE-OFF-'||v_sale_off::text,1,0,1);
  INSERT INTO public.sale_items(sale_id,item_id,product_code,product_name,
    category_name,quantity,unit_price,unit_cost,subtotal,gross_profit)
  VALUES(v_sale_off,v_sold_item,'RULE-RECIPE','QA recipe','QA',1,1,0,1,1);
  UPDATE public.inventory_stock SET quantity_on_hand=0
  WHERE restaurant_id=v_restaurant AND item_id=v_raw_item;
  BEGIN
    PERFORM public.pos_apply_recipe_inventory_movements(v_restaurant,v_sale_off,'sale');
    RAISE EXCEPTION 'disabled_rule_allowed_raw_negative';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  IF EXISTS(SELECT 1 FROM public.inventory_movements
    WHERE reference_id=v_sale_off::text AND movement_type='recipe_consumption') THEN
    RAISE EXCEPTION 'disabled_rule_left_partial_movements';
  END IF;

  UPDATE public.inventory_stock SET quantity_on_hand=0
  WHERE restaurant_id=v_restaurant AND item_id IN (v_product_item,v_packaging_item);
  BEGIN
    PERFORM public.apply_inventory_movement_v2('negative-product-'||gen_random_uuid(),
      v_restaurant,v_product_item,NULL,'sale',-1,'test','sale-product',NULL,NULL,now(),0);
    RAISE EXCEPTION 'sale_product_negative_allowed';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM public.apply_inventory_movement_v2('negative-packaging-'||gen_random_uuid(),
      v_restaurant,v_packaging_item,NULL,'sale',-1,'test','packaging',NULL,NULL,now(),0);
    RAISE EXCEPTION 'packaging_negative_allowed';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  IF has_function_privilege('authenticated',
    'public.apply_inventory_movement_v2(text,uuid,uuid,uuid,text,numeric,text,text,text,text,timestamptz,numeric)',
    'EXECUTE') OR has_function_privilege('authenticated',
    'public.pos_apply_recipe_inventory_movements(uuid,uuid,text)','EXECUTE') THEN
    RAISE EXCEPTION 'internal_movement_rpc_exposed_to_authenticated';
  END IF;
  RAISE NOTICE 'PASS: recipe raw-material negative rule, atomic rejection, reversal, idempotency, strict other item classes, ACL';
END
$test$;
ROLLBACK;
