-- KIVO ITEM CORE / F1.1 RPC SECURITY AND INTEGRITY REVIEW DRAFT
-- DO NOT EXECUTE on the principal lab or production.
-- Requires ITEM_CORE_F1_DDL_DRAFT.sql in an isolated database.
-- Authorization uses auth.uid() plus profiles/roles/permissions.

CREATE OR REPLACE FUNCTION public.app_item_has_write_access(
  p_restaurant_id uuid, p_permission_code text
) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp SET row_security = off AS $$
  SELECT auth.uid() IS NOT NULL
    AND p_permission_code IN ('articulos.gestionar','inventario.gestionar')
    AND EXISTS (SELECT 1 FROM public.profiles actor
      JOIN public.roles role_row ON role_row.id=actor.role_id
        AND role_row.is_active=true
        AND (role_row.restaurant_id IS NULL OR role_row.restaurant_id=p_restaurant_id)
      JOIN public.role_permissions grant_row ON grant_row.role_id=actor.role_id
      JOIN public.permissions permission_row ON permission_row.id=grant_row.permission_id
        AND permission_row.code=p_permission_code
      WHERE actor.id=auth.uid() AND actor.restaurant_id=p_restaurant_id
        AND actor.is_active=true AND actor.is_pos_user=false);
$$;

CREATE OR REPLACE FUNCTION public.item_movement_request_digest(
  p_id text,p_restaurant_id uuid,p_item_id uuid,p_movement_type text,
  p_quantity_delta numeric,p_source_type text,p_source_id text,
  p_operation_key text,p_unit_cost_base numeric,p_reversal_of_id text,
  p_device_id uuid,p_actor_id uuid,p_occurred_at timestamptz
) RETURNS text LANGUAGE sql IMMUTABLE SET search_path=pg_catalog AS $$
  SELECT md5(convert_to(jsonb_build_object(
    'id',p_id,'restaurant_id',p_restaurant_id,'item_id',p_item_id,
    'movement_type',p_movement_type,'quantity_delta',p_quantity_delta,
    'source_type',p_source_type,'source_id',p_source_id,
    'operation_key',p_operation_key,'unit_cost_base',p_unit_cost_base,
    'reversal_of_id',p_reversal_of_id,'device_id',p_device_id,
    'actor_id',p_actor_id,'occurred_at',p_occurred_at)::text,'UTF8'));
$$;

CREATE OR REPLACE FUNCTION public.app_upsert_item(p_restaurant_id uuid,p_payload jsonb)
RETURNS public.items LANGUAGE plpgsql SECURITY DEFINER
SET search_path=public,pg_temp SET row_security=off AS $$
DECLARE
  result public.items; existing_id uuid; requested_type text; requested_base uuid;
  unit_json jsonb; class_id uuid; has_movements boolean;
  base_unit public.measurement_units; candidate_unit public.measurement_units;
BEGIN
  IF NOT public.app_item_has_write_access(p_restaurant_id,'articulos.gestionar')
    THEN RAISE EXCEPTION 'item_write_not_authorized'; END IF;
  IF p_payload IS NULL OR jsonb_typeof(p_payload)<>'object'
    THEN RAISE EXCEPTION 'invalid_item_payload'; END IF;
  IF NULLIF(p_payload->>'id','') IS NOT NULL THEN
    SELECT id INTO existing_id FROM public.items WHERE id=(p_payload->>'id')::uuid
      AND restaurant_id=p_restaurant_id FOR UPDATE;
    IF existing_id IS NULL THEN RAISE EXCEPTION 'item_not_found_or_cross_tenant'; END IF;
  ELSE
    SELECT id INTO existing_id FROM public.items WHERE restaurant_id=p_restaurant_id
      AND lower(btrim(code))=lower(btrim(p_payload->>'code')) FOR UPDATE;
  END IF;
  IF existing_id IS NULL THEN
    IF NOT (p_payload ? 'code' AND p_payload ? 'name' AND p_payload ? 'item_type'
      AND p_payload ? 'base_unit_id') THEN
      RAISE EXCEPTION 'item_create_requires_code_name_type_and_base_unit';
    END IF;
    INSERT INTO public.items(restaurant_id,code,name,item_type,category_id,base_unit_id,
      base_unit_cost,base_unit_price,can_sell,can_purchase,visible_in_pos,uses_recipe,
      send_to_kitchen,is_active) VALUES (p_restaurant_id,btrim(p_payload->>'code'),
      btrim(p_payload->>'name'),p_payload->>'item_type',NULLIF(p_payload->>'category_id','')::uuid,
      (p_payload->>'base_unit_id')::uuid,COALESCE((p_payload->>'base_unit_cost')::numeric,0),
      COALESCE((p_payload->>'base_unit_price')::numeric,0),COALESCE((p_payload->>'can_sell')::boolean,false),
      COALESCE((p_payload->>'can_purchase')::boolean,false),COALESCE((p_payload->>'visible_in_pos')::boolean,false),
      COALESCE((p_payload->>'uses_recipe')::boolean,false),COALESCE((p_payload->>'send_to_kitchen')::boolean,false),
      COALESCE((p_payload->>'is_active')::boolean,true)) RETURNING * INTO result;
  ELSE
    SELECT * INTO result FROM public.items WHERE id=existing_id FOR UPDATE;
    requested_type=CASE WHEN p_payload ? 'item_type' THEN p_payload->>'item_type' ELSE result.item_type END;
    requested_base=CASE WHEN p_payload ? 'base_unit_id' THEN (p_payload->>'base_unit_id')::uuid ELSE result.base_unit_id END;
    SELECT EXISTS(SELECT 1 FROM public.item_ledger_entries WHERE restaurant_id=p_restaurant_id AND item_id=result.id) INTO has_movements;
    IF has_movements AND requested_type<>result.item_type THEN RAISE EXCEPTION 'item_type_change_blocked_by_movements'; END IF;
    IF has_movements AND requested_base<>result.base_unit_id THEN RAISE EXCEPTION 'base_unit_change_blocked_by_movements'; END IF;
    IF p_payload ? 'is_active' AND (p_payload->>'is_active')::boolean=false AND EXISTS(
      SELECT 1 FROM public.item_stock WHERE restaurant_id=p_restaurant_id AND item_id=result.id AND quantity_on_hand<>0)
      THEN RAISE EXCEPTION 'item_inactivation_blocked_by_stock'; END IF;
    UPDATE public.items SET
      code=CASE WHEN p_payload ? 'code' THEN btrim(p_payload->>'code') ELSE code END,
      name=CASE WHEN p_payload ? 'name' THEN btrim(p_payload->>'name') ELSE name END,
      item_type=requested_type,base_unit_id=requested_base,
      category_id=CASE WHEN p_payload ? 'category_id' THEN NULLIF(p_payload->>'category_id','')::uuid ELSE category_id END,
      base_unit_cost=CASE WHEN p_payload ? 'base_unit_cost' THEN (p_payload->>'base_unit_cost')::numeric ELSE base_unit_cost END,
      base_unit_price=CASE WHEN p_payload ? 'base_unit_price' THEN (p_payload->>'base_unit_price')::numeric ELSE base_unit_price END,
      can_sell=CASE WHEN p_payload ? 'can_sell' THEN (p_payload->>'can_sell')::boolean ELSE can_sell END,
      can_purchase=CASE WHEN p_payload ? 'can_purchase' THEN (p_payload->>'can_purchase')::boolean ELSE can_purchase END,
      visible_in_pos=CASE WHEN p_payload ? 'visible_in_pos' THEN (p_payload->>'visible_in_pos')::boolean ELSE visible_in_pos END,
      uses_recipe=CASE WHEN p_payload ? 'uses_recipe' THEN (p_payload->>'uses_recipe')::boolean ELSE uses_recipe END,
      send_to_kitchen=CASE WHEN p_payload ? 'send_to_kitchen' THEN (p_payload->>'send_to_kitchen')::boolean ELSE send_to_kitchen END,
      is_active=CASE WHEN p_payload ? 'is_active' THEN (p_payload->>'is_active')::boolean ELSE is_active END,updated_at=now()
      WHERE id=result.id AND restaurant_id=p_restaurant_id RETURNING * INTO result;
  END IF;
  SELECT * INTO base_unit FROM public.measurement_units WHERE id=result.base_unit_id AND is_active=true
    AND (restaurant_id IS NULL OR restaurant_id=p_restaurant_id);
  IF base_unit.id IS NULL THEN RAISE EXCEPTION 'base_unit_not_found_or_inactive'; END IF;
  INSERT INTO public.item_units(restaurant_id,item_id,unit_id,quantity_in_base,is_active)
    VALUES(p_restaurant_id,result.id,result.base_unit_id,1,true)
    ON CONFLICT(restaurant_id,item_id,unit_id) DO UPDATE SET quantity_in_base=1,is_active=true;
  IF p_payload ? 'units' THEN
    FOR unit_json IN SELECT value FROM jsonb_array_elements(p_payload->'units') LOOP
      SELECT * INTO candidate_unit FROM public.measurement_units WHERE id=(unit_json->>'unit_id')::uuid
        AND is_active=true AND (restaurant_id IS NULL OR restaurant_id=p_restaurant_id);
      IF candidate_unit.id IS NULL THEN RAISE EXCEPTION 'unit_not_found_or_inactive'; END IF;
      IF candidate_unit.unit_group<>base_unit.unit_group THEN RAISE EXCEPTION 'unit_dimension_group_mismatch'; END IF;
      IF (unit_json->>'quantity_in_base')::numeric<=0 THEN RAISE EXCEPTION 'invalid_unit_conversion'; END IF;
      INSERT INTO public.item_units(restaurant_id,item_id,unit_id,quantity_in_base,is_purchase,is_sale)
        VALUES(p_restaurant_id,result.id,candidate_unit.id,(unit_json->>'quantity_in_base')::numeric,
          COALESCE((unit_json->>'is_purchase')::boolean,false),COALESCE((unit_json->>'is_sale')::boolean,false))
        ON CONFLICT(restaurant_id,item_id,unit_id) DO UPDATE SET quantity_in_base=EXCLUDED.quantity_in_base,
          is_purchase=EXCLUDED.is_purchase,is_sale=EXCLUDED.is_sale,is_active=true;
    END LOOP;
  END IF;
  IF EXISTS(SELECT 1 FROM public.item_units WHERE restaurant_id=p_restaurant_id AND item_id=result.id
    AND unit_id=result.base_unit_id AND quantity_in_base<>1) THEN RAISE EXCEPTION 'base_unit_conversion_must_be_one'; END IF;
  IF p_payload ? 'classification_ids' THEN
    DELETE FROM public.item_classification_links WHERE restaurant_id=p_restaurant_id AND item_id=result.id;
    FOR class_id IN SELECT value::uuid FROM jsonb_array_elements_text(p_payload->'classification_ids') LOOP
      IF NOT EXISTS(SELECT 1 FROM public.item_classifications WHERE id=class_id AND restaurant_id=p_restaurant_id AND is_active=true)
        THEN RAISE EXCEPTION 'classification_not_found_or_inactive'; END IF;
      INSERT INTO public.item_classification_links(restaurant_id,item_id,classification_id) VALUES(p_restaurant_id,result.id,class_id);
    END LOOP;
  END IF;
  RETURN result;
EXCEPTION WHEN unique_violation THEN RAISE EXCEPTION 'item_code_or_unit_conflict';
END; $$;

CREATE OR REPLACE FUNCTION public.apply_item_movement(
  p_id text,p_restaurant_id uuid,p_item_id uuid,p_movement_type text,p_quantity_delta numeric,
  p_source_type text,p_source_id text,p_operation_key text,p_request_digest text,p_unit_cost_base numeric=0,
  p_reversal_of_id text=NULL,p_device_id uuid=NULL,p_actor_id uuid=NULL,p_occurred_at timestamptz=now())
RETURNS public.item_ledger_entries LANGUAGE plpgsql SECURITY DEFINER
SET search_path=public,pg_temp SET row_security=off AS $$
DECLARE item_row public.items; prior public.item_ledger_entries; original public.item_ledger_entries;
  result public.item_ledger_entries; current_qty numeric; effective_actor uuid; expected_digest text;
BEGIN
  IF NOT public.app_item_has_write_access(p_restaurant_id,'inventario.gestionar') THEN RAISE EXCEPTION 'movement_not_authorized'; END IF;
  effective_actor=COALESCE(p_actor_id,auth.uid());
  IF effective_actor IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'actor_mismatch'; END IF;
  IF p_id IS NULL OR length(btrim(p_id))=0 OR p_quantity_delta=0 OR p_source_type IS NULL OR length(btrim(p_source_type))=0
    OR p_source_id IS NULL OR length(btrim(p_source_id))=0 OR p_operation_key IS NULL OR length(btrim(p_operation_key))=0
    OR p_request_digest IS NULL OR length(btrim(p_request_digest))=0 OR p_movement_type NOT IN
      ('opening','purchase','sale','recipe_consumption','packaging_consumption','staff_consumption','adjustment','reversal')
    THEN RAISE EXCEPTION 'invalid_movement_payload'; END IF;
  IF p_device_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.pos_devices WHERE id=p_device_id
    AND restaurant_id=p_restaurant_id AND is_active=true) THEN RAISE EXCEPTION 'device_not_found_or_inactive'; END IF;
  expected_digest=public.item_movement_request_digest(p_id,p_restaurant_id,p_item_id,p_movement_type,p_quantity_delta,p_source_type,p_source_id,
    p_operation_key,p_unit_cost_base,p_reversal_of_id,p_device_id,effective_actor,p_occurred_at);
  IF p_request_digest<>expected_digest THEN RAISE EXCEPTION 'request_digest_mismatch'; END IF;
  SELECT * INTO prior FROM public.item_ledger_entries WHERE restaurant_id=p_restaurant_id AND operation_key=p_operation_key FOR UPDATE;
  IF prior.id IS NOT NULL THEN
    IF prior.request_digest<>expected_digest OR prior.id<>p_id THEN RAISE EXCEPTION 'idempotency_payload_mismatch'; END IF;
    RETURN prior;
  END IF;
  SELECT * INTO item_row FROM public.items WHERE id=p_item_id AND restaurant_id=p_restaurant_id FOR SHARE;
  IF item_row.id IS NULL THEN RAISE EXCEPTION 'item_not_found_or_cross_tenant'; END IF;
  IF item_row.item_type<>'inventory' OR item_row.is_active=false THEN RAISE EXCEPTION 'item_type_or_status_has_no_physical_stock'; END IF;
  IF p_movement_type='reversal' THEN
    IF p_reversal_of_id IS NULL THEN RAISE EXCEPTION 'reversal_requires_original'; END IF;
    SELECT * INTO original FROM public.item_ledger_entries WHERE id=p_reversal_of_id FOR SHARE;
    IF original.id IS NULL OR original.restaurant_id<>p_restaurant_id OR original.item_id<>p_item_id OR original.movement_type='reversal'
      THEN RAISE EXCEPTION 'invalid_reversal_original'; END IF;
    IF p_quantity_delta<>-original.quantity_delta OR p_unit_cost_base<>original.unit_cost_base
      THEN RAISE EXCEPTION 'reversal_quantity_or_cost_mismatch'; END IF;
  ELSIF p_reversal_of_id IS NOT NULL THEN RAISE EXCEPTION 'only_reversal_can_reference_original'; END IF;
  INSERT INTO public.item_stock(restaurant_id,item_id) VALUES(p_restaurant_id,p_item_id) ON CONFLICT DO NOTHING;
  SELECT quantity_on_hand INTO current_qty FROM public.item_stock WHERE restaurant_id=p_restaurant_id AND item_id=p_item_id FOR UPDATE;
  IF current_qty+p_quantity_delta<0 THEN RAISE EXCEPTION 'insufficient_stock'; END IF;
  INSERT INTO public.item_ledger_entries(id,restaurant_id,item_id,movement_type,quantity_delta,unit_cost_base,source_type,source_id,
    operation_key,request_digest,reversal_of_id,device_id,actor_id,occurred_at) VALUES(p_id,p_restaurant_id,p_item_id,p_movement_type,
    p_quantity_delta,p_unit_cost_base,p_source_type,p_source_id,p_operation_key,expected_digest,p_reversal_of_id,p_device_id,effective_actor,p_occurred_at)
    RETURNING * INTO result;
  UPDATE public.item_stock SET quantity_on_hand=current_qty+p_quantity_delta,version=version+1,updated_at=now()
    WHERE restaurant_id=p_restaurant_id AND item_id=p_item_id;
  IF (SELECT quantity_on_hand FROM public.item_stock WHERE restaurant_id=p_restaurant_id AND item_id=p_item_id)<>(
    SELECT COALESCE(sum(quantity_delta),0) FROM public.item_ledger_entries WHERE restaurant_id=p_restaurant_id AND item_id=p_item_id)
    THEN RAISE EXCEPTION 'stock_projection_mismatch'; END IF;
  RETURN result;
EXCEPTION WHEN unique_violation THEN RAISE EXCEPTION 'movement_conflict';
END; $$;

CREATE OR REPLACE FUNCTION public.item_ledger_append_only_guard() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$ BEGIN RAISE EXCEPTION 'item_ledger_append_only'; END; $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid='public.item_ledger_entries'::regclass
    AND tgname='item_ledger_append_only_guard' AND NOT tgisinternal) THEN
    CREATE TRIGGER item_ledger_append_only_guard BEFORE UPDATE OR DELETE
      ON public.item_ledger_entries FOR EACH ROW
      EXECUTE FUNCTION public.item_ledger_append_only_guard();
  END IF;
END $$;

REVOKE ALL ON FUNCTION public.app_item_has_write_access(uuid,text),
  public.item_movement_request_digest(text,uuid,uuid,text,numeric,text,text,text,numeric,text,uuid,uuid,timestamptz),
  public.app_upsert_item(uuid,jsonb),public.apply_item_movement(text,uuid,uuid,text,numeric,text,text,text,text,numeric,text,uuid,uuid,timestamptz)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.app_upsert_item(uuid,jsonb),public.apply_item_movement(text,uuid,uuid,text,numeric,text,text,text,text,numeric,text,uuid,uuid,timestamptz) TO authenticated;
