-- Gives inventory adjustment lines an explicit canonical item identity.
ALTER TABLE public.inventory_adjustment_lines
  ADD COLUMN IF NOT EXISTS item_id uuid REFERENCES public.items(id);

UPDATE public.inventory_adjustment_lines AS line
SET item_id = line.product_id
WHERE line.item_id IS NULL
  AND line.product_id IS NOT NULL
  AND EXISTS (SELECT 1 FROM public.items i WHERE i.id = line.product_id);

CREATE INDEX IF NOT EXISTS inventory_adjustment_lines_item_idx
  ON public.inventory_adjustment_lines (document_id, item_id);
