CREATE OR REPLACE FUNCTION public.app_get_product_performance_report(
  p_restaurant_id uuid,
  p_from date,
  p_to date
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.app_assert_admin_permission(p_restaurant_id, 'reportes.ver');

  IF p_to < p_from THEN
    RAISE EXCEPTION 'La fecha final no puede ser menor que la fecha inicial';
  END IF;

  RETURN COALESCE((
    SELECT jsonb_agg(
      jsonb_build_object(
        'product_id', row_data.product_id,
        'product_name', row_data.product_name,
        'category_name', row_data.category_name,
        'quantity_sold', row_data.quantity_sold,
        'sales_amount', row_data.sales_amount,
        'cost_amount', row_data.cost_amount,
        'gross_profit_amount', row_data.gross_profit_amount
      )
      ORDER BY row_data.gross_profit_amount DESC, row_data.quantity_sold DESC
    )
    FROM (
      SELECT
        COALESCE(item.product_id::text, 'name:' || lower(item.product_name))
          AS product_id,
        item.product_name,
        COALESCE(NULLIF(item.category_name, ''), 'Sin categoria')
          AS category_name,
        SUM(item.quantity)::numeric AS quantity_sold,
        SUM(item.quantity * item.unit_price)::numeric AS sales_amount,
        SUM(item.quantity * item.unit_cost)::numeric AS cost_amount,
        SUM(item.quantity * (item.unit_price - item.unit_cost))::numeric
          AS gross_profit_amount
      FROM public.sales sale
      JOIN public.sale_items item ON item.sale_id = sale.id
      WHERE sale.restaurant_id = p_restaurant_id
        AND sale.status = 'completed'
        AND sale.sale_kind = 'sale'
        AND sale.sold_at >= p_from::timestamptz
        AND sale.sold_at < (p_to + 1)::timestamptz
      GROUP BY
        COALESCE(item.product_id::text, 'name:' || lower(item.product_name)),
        item.product_name,
        COALESCE(NULLIF(item.category_name, ''), 'Sin categoria')
    ) row_data
  ), '[]'::jsonb);
END;
$$;

REVOKE ALL ON FUNCTION public.app_get_product_performance_report(uuid, date, date)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.app_get_product_performance_report(uuid, date, date)
  TO authenticated;
