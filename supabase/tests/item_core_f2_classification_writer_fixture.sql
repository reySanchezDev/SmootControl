-- Disposable PostgreSQL fixture. Starts inside POS sale BEGIN.
-- Master and link tables are now created in the shared catalog fixture.
INSERT INTO public.item_classifications(id,restaurant_id,code,is_active) VALUES
 ('90000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001','PACKAGING',true),
 ('90000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000002','PACKAGING',true),
 ('90000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000001','ARCHIVED',false);
INSERT INTO public.item_catalog_revisions(restaurant_id)
VALUES('00000000-0000-0000-0000-000000000001');
SELECT set_config('app.can_write_inventory','true',true);
