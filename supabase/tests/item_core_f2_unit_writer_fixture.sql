-- Disposable fixture; the POS sale fixture already opened BEGIN.
ALTER TABLE public.items ADD COLUMN visible_in_pos boolean NOT NULL DEFAULT false;
CREATE TABLE public.item_units(
  restaurant_id uuid NOT NULL,
  item_id uuid NOT NULL,
  unit_id uuid NOT NULL,
  quantity_in_base numeric(18,8) NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  PRIMARY KEY(restaurant_id,item_id,unit_id),
  FOREIGN KEY(restaurant_id,item_id) REFERENCES public.items(restaurant_id,id),
  FOREIGN KEY(unit_id) REFERENCES public.measurement_units(id)
);
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
INSERT INTO public.item_units(
  restaurant_id,item_id,unit_id,quantity_in_base,is_active
)
SELECT i.restaurant_id,i.id,i.base_unit_id,1,true
FROM public.items i;
INSERT INTO public.item_catalog_revisions(restaurant_id)
VALUES('00000000-0000-0000-0000-000000000001');
SELECT set_config('app.can_write_inventory','true',true);
