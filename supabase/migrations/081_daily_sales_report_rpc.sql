CREATE OR REPLACE FUNCTION public.app_get_daily_sales_report(
  p_restaurant_id uuid,
  p_from date,
  p_to date,
  p_timezone text DEFAULT 'America/Managua'
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
    WITH selected_sales AS (
      SELECT
        sale.id,
        (sale.sold_at AT TIME ZONE p_timezone)::date AS business_date,
        sale.total_amount
      FROM public.sales sale
      WHERE sale.restaurant_id = p_restaurant_id
        AND sale.status = 'completed'
        AND sale.sale_kind = 'sale'
        AND sale.sold_at >= (p_from::timestamp AT TIME ZONE p_timezone)
        AND sale.sold_at < ((p_to + 1)::timestamp AT TIME ZONE p_timezone)
    ),
    sales_by_day AS (
      SELECT
        business_date,
        SUM(total_amount)::numeric AS sales_amount
      FROM selected_sales
      GROUP BY business_date
    ),
    costs_by_day AS (
      SELECT
        sale.business_date,
        SUM(item.quantity * item.unit_cost)::numeric AS cost_amount
      FROM selected_sales sale
      JOIN public.sale_items item ON item.sale_id = sale.id
      GROUP BY sale.business_date
    )
    SELECT jsonb_agg(
      jsonb_build_object(
        'date', COALESCE(sales.business_date, costs.business_date),
        'sales_amount', COALESCE(sales.sales_amount, 0),
        'cost_amount', COALESCE(costs.cost_amount, 0)
      )
      ORDER BY COALESCE(sales.business_date, costs.business_date)
    )
    FROM sales_by_day sales
    FULL JOIN costs_by_day costs
      ON costs.business_date = sales.business_date
  ), '[]'::jsonb);
END;
$$;

REVOKE ALL ON FUNCTION public.app_get_daily_sales_report(
  uuid,
  date,
  date,
  text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.app_get_daily_sales_report(
  uuid,
  date,
  date,
  text
) TO authenticated;
