-- Disposable fixture; the POS sale fixture already opened BEGIN.
ALTER TABLE public.item_units
  ADD COLUMN is_purchase boolean NOT NULL DEFAULT false,
  ADD COLUMN is_sale boolean NOT NULL DEFAULT false;
ALTER TABLE public.measurement_units
  ADD CONSTRAINT item_core_fixture_unit_tenant_check
  CHECK(restaurant_id IS NULL OR restaurant_id IN (
    '00000000-0000-0000-0000-000000000001'::uuid,
    '00000000-0000-0000-0000-000000000002'::uuid
  ));
INSERT INTO public.measurement_units(
  id,restaurant_id,unit_group,base_factor,is_active
) VALUES
 ('10000000-0000-0000-0000-000000000002',NULL,'count',12,true),
 ('10000000-0000-0000-0000-000000000003',NULL,'volume',1,true),
 ('10000000-0000-0000-0000-000000000004',
  '00000000-0000-0000-0000-000000000002','count',6,true);
INSERT INTO public.item_catalog_revisions(restaurant_id)
VALUES('00000000-0000-0000-0000-000000000001');
SELECT set_config('app.can_write_inventory','true',true);
