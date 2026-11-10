-- KIVO F2 / CONSUMPTION RULE RESOLUTION (DESIGN DRAFT)
-- NOT A MIGRATION. Run only on isolated copies with F1 schema.
-- Read-only resolution: does not modify items, ledger, stock, sales or rules.
-- Design decision: a rule set is selected per (scope, source-item, consumed-item).
-- Exact service type wins, then exact source-item, then priority; ties reject.
-- Per-order rules are evaluated once; per-line rules multiply source line qty.
-- Per-order rules may be global or scoped to one item present in order.
-- Excludes non-inventory/service consumption: no physical quantity to move.
-- The caller must persist rule IDs and quantities with transaction snapshot in F2.
-- DO NOT use output to book inventory until one atomic POS sale RPC exists.

CREATE OR REPLACE FUNCTION public.resolve_item_consumption(
  p_restaurant_id uuid,
  p_sales_type_id uuid,
  p_sale_lines jsonb
)
RETURNS TABLE(
  rule_id uuid,
  consumed_item_id uuid,
  quantity_base numeric,
  scope text,
  source_item_id uuid,
  unit_id uuid
)
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_line jsonb;
  v_line_item uuid;
  v_line_quantity numeric;
  v_result record;
BEGIN
  IF p_restaurant_id IS NULL OR p_restaurant_id IS DISTINCT FROM
    public.current_restaurant_id() THEN
    RAISE EXCEPTION 'consumption_tenant_not_authorized'
      USING ERRCODE = '42501';
  END IF;

  IF p_sale_lines IS NULL OR jsonb_typeof(p_sale_lines) <> 'array'
  THEN
    RAISE EXCEPTION 'invalid_sale_lines' USING ERRCODE = '22023';
  END IF;

  IF jsonb_array_length(p_sale_lines) = 0 THEN
    RAISE EXCEPTION 'empty_sale_lines' USING ERRCODE = '22023';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.sales_types st
    WHERE st.id = p_sales_type_id AND st.restaurant_id = p_restaurant_id
      AND st.is_active = true
  ) THEN
    RAISE EXCEPTION 'sales_type_not_found_or_inactive'
      USING ERRCODE = '23503';
  END IF;

  -- Every order line must be a known, active, sellable article from the tenant.
  -- The source line id is relevant to sales idempotency but not to rule amounts.
  FOR v_line IN SELECT value FROM jsonb_array_elements(p_sale_lines)
  LOOP
    IF jsonb_typeof(v_line) <> 'object' THEN
      RAISE EXCEPTION 'invalid_sale_line' USING ERRCODE = '22023';
    END IF;
    v_line_item := NULLIF(v_line ->> 'item_id', '')::uuid;
    v_line_quantity := NULLIF(v_line ->> 'quantity', '')::numeric;
    IF v_line_item IS NULL OR v_line_quantity IS NULL
       OR v_line_quantity <= 0 OR v_line_quantity > 1000000 THEN
      RAISE EXCEPTION 'invalid_sale_line_quantity_or_item'
        USING ERRCODE = '22023';
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM public.items i
      WHERE i.id = v_line_item AND i.restaurant_id = p_restaurant_id
        AND i.is_active AND i.can_sell
    ) THEN
      RAISE EXCEPTION 'sale_item_not_found_or_not_sellable'
        USING ERRCODE = '23503';
    END IF;
  END LOOP;

  -- Duplicate item lines are aggregated; per-order rules apply once to an order.
  -- Resolver precedence is per-scope and consumed item (not summed across
  -- overlapping tenant-wide versus item-specific rules).
  FOR v_result IN
  WITH lines AS (
    SELECT (value ->> 'item_id')::uuid AS item_id,
           sum((value ->> 'quantity')::numeric) AS quantity
    FROM jsonb_array_elements(p_sale_lines)
    GROUP BY (value ->> 'item_id')::uuid
  ),
  candidates AS (
    SELECT r.id, r.consumed_item_id, r.scope, r.source_item_id,
           r.unit_id, r.quantity AS rule_quantity,
           CASE WHEN r.source_item_id IS NOT NULL THEN l.quantity
                ELSE 1::numeric END AS order_quantity,
           r.priority,
           CASE WHEN r.sales_type_id IS NOT NULL THEN 1 ELSE 0 END
             AS sales_type_specificity,
           CASE WHEN r.source_item_id IS NOT NULL THEN 1 ELSE 0 END
             AS item_specificity
    FROM public.item_consumption_rules r
    JOIN public.items consumed
      ON consumed.id = r.consumed_item_id
     AND consumed.restaurant_id = r.restaurant_id
     AND consumed.item_type = 'inventory'
     AND consumed.is_active = true
    LEFT JOIN lines l ON l.item_id = r.source_item_id
    WHERE r.restaurant_id = p_restaurant_id AND r.is_active = true
      AND (r.sales_type_id IS NULL OR r.sales_type_id = p_sales_type_id)
      AND (r.source_item_id IS NULL OR l.item_id IS NOT NULL)
  ),
  -- Per-line requires explicit source; per-order can match an item in order.
  eligible AS (
    SELECT *
    FROM candidates
    WHERE (scope = 'per_order')
       OR (scope = 'per_sale_line' AND source_item_id IS NOT NULL)
  ),
  ranked AS (
    SELECT e.*,
      dense_rank() OVER (
        PARTITION BY e.scope,
          CASE WHEN e.scope = 'per_order' THEN NULL ELSE e.source_item_id END,
          e.consumed_item_id
        ORDER BY e.sales_type_specificity DESC,
                 e.item_specificity DESC, e.priority ASC
      ) AS rank_in_bucket
    FROM eligible e
  ),
  selected AS (
    SELECT * FROM ranked WHERE rank_in_bucket = 1
  ),
  resolved AS (
    SELECT s.*,
           mu.base_factor AS source_unit_factor,
           base_mu.base_factor AS base_unit_factor,
           (mu.unit_group IS NOT NULL AND base_mu.unit_group IS NOT NULL
             AND mu.unit_group = base_mu.unit_group
             AND mu.is_active AND base_mu.is_active
             AND (mu.restaurant_id IS NULL OR mu.restaurant_id = p_restaurant_id)
             AND (base_mu.restaurant_id IS NULL
               OR base_mu.restaurant_id = p_restaurant_id)
           ) AS units_compatible,
           count(*) OVER (
             PARTITION BY s.scope,
               CASE WHEN s.scope = 'per_order' THEN NULL ELSE s.source_item_id END,
               s.consumed_item_id
           ) AS candidates_at_best_rank
    FROM selected s
    JOIN public.items consumed
      ON consumed.id = s.consumed_item_id
     AND consumed.restaurant_id = p_restaurant_id
    LEFT JOIN public.measurement_units mu
      ON mu.id = s.unit_id
    LEFT JOIN public.measurement_units base_mu
      ON base_mu.id = consumed.base_unit_id
  )
  SELECT s.id AS rule_id, s.consumed_item_id,
         (s.rule_quantity * CASE WHEN s.scope = 'per_order' THEN 1
           ELSE s.order_quantity END *
           s.source_unit_factor / s.base_unit_factor)::numeric AS quantity_base,
         s.scope, s.source_item_id, s.unit_id,
         s.units_compatible, s.candidates_at_best_rank
  FROM resolved s
  LOOP
    IF v_result.candidates_at_best_rank > 1 THEN
      RAISE EXCEPTION 'ambiguous_consumption_rules' USING ERRCODE = '23514';
    END IF;
    IF v_result.units_compatible IS DISTINCT FROM true
       OR v_result.quantity_base IS NULL OR v_result.quantity_base <= 0 THEN
      RAISE EXCEPTION 'invalid_consumption_rule_unit' USING ERRCODE = '23514';
    END IF;
    rule_id := v_result.rule_id;
    consumed_item_id := v_result.consumed_item_id;
    quantity_base := v_result.quantity_base;
    scope := v_result.scope;
    source_item_id := v_result.source_item_id;
    unit_id := v_result.unit_id;
    RETURN NEXT;
  END LOOP;
  RETURN;
END;
$$;

-- No GRANT to anon. Even authenticated callers use tenant-scoped RLS.
REVOKE ALL ON FUNCTION public.resolve_item_consumption(uuid,uuid,jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.resolve_item_consumption(uuid,uuid,jsonb)
  TO authenticated;
