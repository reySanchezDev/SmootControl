-- Disposable PostgreSQL fixture. Starts inside POS sale BEGIN.
CREATE TABLE public.item_classifications(
  id uuid PRIMARY KEY,
  restaurant_id uuid NOT NULL,
  code text NOT NULL,
  is_active boolean NOT NULL,
  UNIQUE(restaurant_id,id)
);
CREATE TABLE public.item_classification_links(
  restaurant_id uuid NOT NULL,
  item_id uuid NOT NULL,
  classification_id uuid NOT NULL,
  PRIMARY KEY(restaurant_id,item_id,classification_id),
  FOREIGN KEY(restaurant_id,item_id) REFERENCES public.items(restaurant_id,id),
  FOREIGN KEY(restaurant_id,classification_id)
    REFERENCES public.item_classifications(restaurant_id,id)
);
INSERT INTO public.item_classifications VALUES
 ('90000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001','PACKAGING',true),
 ('90000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000002','PACKAGING',true),
 ('90000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000001','ARCHIVED',false);
INSERT INTO public.item_catalog_revisions(restaurant_id)
VALUES('00000000-0000-0000-0000-000000000001');
SELECT set_config('app.can_write_inventory','true',true);
