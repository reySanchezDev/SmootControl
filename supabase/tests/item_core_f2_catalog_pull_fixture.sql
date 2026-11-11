-- Fixture appended after item_core_f2_pos_sale_fixture.sql in a
-- disposable PostgreSQL transaction. Never run against an operating DB.
CREATE SCHEMA item_core_internal;

ALTER TABLE public.items
  ADD COLUMN visible_in_pos boolean NOT NULL DEFAULT false;
UPDATE public.items SET visible_in_pos=true
WHERE code IN ('BOT-1','SRV-1');

CREATE TABLE public.item_units(
  restaurant_id uuid NOT NULL,
  item_id uuid NOT NULL,
  unit_id uuid NOT NULL,
  quantity_in_base numeric(18,8) NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  PRIMARY KEY(restaurant_id,item_id,unit_id)
);
INSERT INTO public.item_units(
  restaurant_id,item_id,unit_id,quantity_in_base
)
SELECT i.restaurant_id,i.id,i.base_unit_id,1
FROM public.items i;

-- F2.3 POS classification export needs all master/link rows, even hidden
-- or inactive classes. These tables are synthetic only.
CREATE TABLE public.item_classifications(
  id uuid PRIMARY KEY,
  restaurant_id uuid NOT NULL,
  code text NOT NULL,
  name text NOT NULL DEFAULT 'Fixture classification',
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
