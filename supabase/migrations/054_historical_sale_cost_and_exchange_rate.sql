-- Freezes sale exchange-rate data and backfills missing historical costs.

ALTER TABLE public.sales
  ADD COLUMN IF NOT EXISTS payment_currency_code text,
  ADD COLUMN IF NOT EXISTS exchange_rate numeric(15, 4);

COMMENT ON COLUMN public.sales.payment_currency_code IS
  'Historical payment currency used by the POS when the sale was completed.';

COMMENT ON COLUMN public.sales.exchange_rate IS
  'Historical exchange rate used by the POS when the sale was completed.';

CREATE OR REPLACE FUNCTION public.app_current_sale_item_unit_cost(
  p_restaurant_id uuid,
  p_product_id uuid
)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  product_row record;
  recipe_cost numeric;
BEGIN
  SELECT cost, uses_recipe
    INTO product_row
    FROM public.products
   WHERE id = p_product_id
     AND restaurant_id = p_restaurant_id
   LIMIT 1;

  IF product_row IS NULL THEN
    RETURN 0;
  END IF;

  IF product_row.uses_recipe THEN
    recipe_cost := public.app_recipe_unit_cost(p_restaurant_id, p_product_id);
    IF recipe_cost > 0 THEN
      RETURN recipe_cost;
    END IF;
  END IF;

  RETURN COALESCE(product_row.cost, 0);
END;
$$;

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
BEGIN
  CREATE TEMP TABLE IF NOT EXISTS tmp_cost_backfill_items (
    sale_id uuid NOT NULL,
    item_id uuid PRIMARY KEY
  ) ON COMMIT DROP;
  TRUNCATE tmp_cost_backfill_items;

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
  INSERT INTO tmp_cost_backfill_items(sale_id, item_id)
  SELECT sale_id, id FROM updated
  ON CONFLICT DO NOTHING;

  GET DIAGNOSTICS updated_items = ROW_COUNT;

  WITH totals AS (
    SELECT
      sale_id,
      COALESCE(SUM(quantity * unit_cost), 0) AS total_cost
    FROM public.sale_items
    WHERE sale_id IN (SELECT sale_id FROM tmp_cost_backfill_items)
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

ALTER FUNCTION public.pos_sync_sale(uuid, uuid, text, jsonb)
RENAME TO pos_sync_sale_historical_snapshot_base_20260716;

CREATE OR REPLACE FUNCTION public.pos_sync_sale(
  p_restaurant_id uuid,
  p_device_id uuid,
  p_device_secret text,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result jsonb;
  sale_payload jsonb;
  synced_sale_id uuid;
BEGIN
  result := public.pos_sync_sale_historical_snapshot_base_20260716(
    p_restaurant_id,
    p_device_id,
    p_device_secret,
    p_payload
  );

  sale_payload := p_payload -> 'sale';
  synced_sale_id := NULLIF(result ->> 'remote_id', '')::uuid;
  IF synced_sale_id IS NOT NULL THEN
    UPDATE public.sales
       SET payment_currency_code = COALESCE(
             NULLIF(upper(sale_payload ->> 'payment_currency_code'), ''),
             payment_currency_code
           ),
           exchange_rate = COALESCE(
             NULLIF(sale_payload ->> 'exchange_rate', '')::numeric,
             exchange_rate
           )
     WHERE id = synced_sale_id
       AND restaurant_id = p_restaurant_id;
  END IF;

  RETURN result;
END;
$$;

ALTER FUNCTION public.pos_sync_staff_consumption(uuid, uuid, text, jsonb)
RENAME TO pos_sync_staff_consumption_historical_snapshot_base_20260716;

CREATE OR REPLACE FUNCTION public.pos_sync_staff_consumption(
  p_restaurant_id uuid,
  p_device_id uuid,
  p_device_secret text,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result jsonb;
  sale_payload jsonb;
  synced_sale_id uuid;
BEGIN
  result := public.pos_sync_staff_consumption_historical_snapshot_base_20260716(
    p_restaurant_id,
    p_device_id,
    p_device_secret,
    p_payload
  );

  sale_payload := p_payload -> 'sale';
  synced_sale_id := NULLIF(result ->> 'remote_id', '')::uuid;
  IF synced_sale_id IS NOT NULL THEN
    UPDATE public.sales
       SET payment_currency_code = COALESCE(
             NULLIF(upper(sale_payload ->> 'payment_currency_code'), ''),
             payment_currency_code
           ),
           exchange_rate = COALESCE(
             NULLIF(sale_payload ->> 'exchange_rate', '')::numeric,
             exchange_rate
           )
     WHERE id = synced_sale_id
       AND restaurant_id = p_restaurant_id;
  END IF;

  RETURN result;
END;
$$;

DO $$
DECLARE
  restaurant_row record;
BEGIN
  FOR restaurant_row IN SELECT id FROM public.restaurants LOOP
    PERFORM public.app_backfill_missing_sale_costs(restaurant_row.id);
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.app_current_sale_item_unit_cost(uuid, uuid)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.app_backfill_missing_sale_costs(uuid)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pos_sync_sale(uuid, uuid, text, jsonb)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pos_sync_staff_consumption(
  uuid,
  uuid,
  text,
  jsonb
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.pos_sync_sale(uuid, uuid, text, jsonb)
  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.pos_sync_staff_consumption(
  uuid,
  uuid,
  text,
  jsonb
) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.app_backfill_missing_sale_costs(uuid)
  TO authenticated, service_role;

COMMENT ON FUNCTION public.app_backfill_missing_sale_costs(uuid) IS
  'Initial production-start backfill: fills sale item costs only when unit_cost is zero.';
