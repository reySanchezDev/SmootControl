-- Fix legacy PL/pgSQL lint (42P01) without changing migration 054.
-- Two SQL statements preserve visibility of new line costs when totaling sales.
-- This migration does not invoke the backfill or mutate any sale data.
BEGIN;
CREATE OR REPLACE FUNCTION public.app_backfill_missing_sale_costs(
  p_restaurant_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  updated_items integer := 0;
  updated_sales integer := 0;
  affected_sale_ids uuid[] := ARRAY[]::uuid[];
BEGIN
  WITH candidates AS (
    SELECT
      item.id,
      item.sale_id,
      public.app_current_sale_item_unit_cost(
        sale.restaurant_id,
        item.product_id
      ) AS new_unit_cost
    FROM public.sale_items item
    JOIN public.sales sale
      ON sale.id = item.sale_id
     AND sale.restaurant_id = p_restaurant_id
    WHERE item.product_id IS NOT NULL
      AND item.unit_cost = 0
      AND sale.status = 'completed'
  ),
  updated AS (
    UPDATE public.sale_items item
       SET unit_cost = candidates.new_unit_cost,
           gross_profit =
             (item.quantity * item.unit_price) -
             (item.quantity * candidates.new_unit_cost)
      FROM candidates
     WHERE item.id = candidates.id
       AND candidates.new_unit_cost > 0
     RETURNING item.sale_id, item.id
  )
  SELECT COALESCE(array_agg(DISTINCT sale_id), ARRAY[]::uuid[]),
         COUNT(*)::integer
  INTO affected_sale_ids, updated_items
  FROM updated;

  WITH totals AS (
    SELECT
      sale_id,
      COALESCE(SUM(quantity * unit_cost), 0) AS total_cost
    FROM public.sale_items
    WHERE sale_id = ANY(affected_sale_ids)
    GROUP BY sale_id
  ),
  updated AS (
    UPDATE public.sales sale
       SET total_cost = totals.total_cost,
           gross_profit = sale.total_amount - totals.total_cost,
           updated_at = now()
      FROM totals
     WHERE sale.id = totals.sale_id
     RETURNING sale.id
  )
  SELECT COUNT(*) INTO updated_sales FROM updated;

  RETURN jsonb_build_object(
    'updated_items',
    updated_items,
    'updated_sales',
    updated_sales
  );
END;
$$;
COMMIT;
