-- Runs after F2 sale schema draft has been stripped of BEGIN/ROLLBACK
-- by workflow (only on disposable PostgreSQL container).
DO $$
DECLARE
 v_line uuid := '40000000-0000-0000-0000-000000000001';
BEGIN
 UPDATE public.sales SET sync_contract_version=2,operation_key='sale-01',
  operation_digest='digest-sale-01'
 WHERE id='30000000-0000-0000-0000-000000000001';

 INSERT INTO public.sale_items(id,sale_id,restaurant_id,item_id,
  item_base_unit_id,item_unit_factor,sync_contract_version)
 VALUES (v_line,'30000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  '50000000-0000-0000-0000-000000000001',1,2);

 INSERT INTO public.sale_consumption_snapshots(
  restaurant_id,sale_id,sale_line_id,scope,consumed_item_id,
  rule_id,quantity_base,unit_cost_base,movement_id
 ) VALUES (
  '00000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  v_line,'per_sale_line',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',2,3,'movement-01'
 );

 IF (SELECT count(*) FROM public.sale_consumption_snapshots) <> 1 THEN
   RAISE EXCEPTION 'snapshot_missing';
 END IF;

 BEGIN
  INSERT INTO public.sale_consumption_snapshots(
   restaurant_id,sale_id,scope,consumed_item_id,
   quantity_base,unit_cost_base,movement_id
  ) VALUES (
   '00000000-0000-0000-0000-000000000002',
   '30000000-0000-0000-0000-000000000001','per_order',
   '10000000-0000-0000-0000-000000000002',1,1,'movement-01');
  RAISE EXCEPTION 'cross_tenant_snapshot_not_rejected';
 EXCEPTION WHEN foreign_key_violation THEN NULL;
 END;

 BEGIN
  INSERT INTO public.sale_items(id,sale_id,sync_contract_version)
  VALUES ('40000000-0000-0000-0000-000000000003',
   '30000000-0000-0000-0000-000000000001',2);
  RAISE EXCEPTION 'missing_v2_item_not_rejected';
 EXCEPTION WHEN check_violation THEN NULL;
 END;

 BEGIN
  INSERT INTO public.sales(id,restaurant_id,sync_contract_version)
  VALUES ('30000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000001',2);
  RAISE EXCEPTION 'v2_without_operation_not_rejected';
 EXCEPTION WHEN check_violation THEN NULL;
 END;

 BEGIN
  INSERT INTO public.sales(id,restaurant_id,sync_contract_version,
    operation_key,operation_digest)
  VALUES ('30000000-0000-0000-0000-000000000004',
    '00000000-0000-0000-0000-000000000001',2,
    'sale-01','digest-different');
  RAISE EXCEPTION 'duplicate_operation_not_rejected';
 EXCEPTION WHEN unique_violation THEN NULL;
 END;

 RAISE NOTICE 'PASS F2 sale schema: snapshots, tenant FKs, V2 contract and operation uniqueness';
END;
$$;
ROLLBACK;
