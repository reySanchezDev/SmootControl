-- Synthetic extension to classification-link fixture (inside BEGIN).
ALTER TABLE public.item_classifications
  ADD COLUMN name text NOT NULL DEFAULT 'Fixture classification';
