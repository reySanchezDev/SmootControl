-- Reports and historical cost helpers read canonical sale item identity.
CREATE OR REPLACE FUNCTION public.app_current_sale_item_unit_cost(
  p_restaurant_id uuid, p_product_id uuid
) RETURNS numeric LANGUAGE sql SECURITY DEFINER
SET search_path = public AS $$
  SELECT CASE WHEN item.uses_recipe THEN
    greatest(public.app_recipe_unit_cost(p_restaurant_id, item.id), item.base_unit_cost)
  ELSE item.base_unit_cost END
  FROM public.items item
  WHERE item.id=p_product_id AND item.restaurant_id=p_restaurant_id;
$$;

CREATE OR REPLACE FUNCTION public.app_get_product_performance_report(
  p_restaurant_id uuid, p_from date, p_to date
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
BEGIN
  PERFORM public.app_assert_admin_permission(p_restaurant_id, 'reportes.ver');
  IF p_to < p_from THEN RAISE EXCEPTION 'La fecha final no puede ser menor que la fecha inicial'; END IF;
  RETURN coalesce((SELECT jsonb_agg(jsonb_build_object(
    'product_id', row_data.item_id, 'product_name', row_data.product_name,
    'category_name', row_data.category_name, 'quantity_sold', row_data.quantity_sold,
    'sales_amount', row_data.sales_amount, 'cost_amount', row_data.cost_amount,
    'gross_profit_amount', row_data.gross_profit_amount)
    ORDER BY row_data.gross_profit_amount DESC,row_data.quantity_sold DESC)
  FROM (SELECT coalesce(item.item_id::text,'name:'||lower(item.product_name)) item_id,
    item.product_name,coalesce(nullif(item.category_name,''),'Sin categoria') category_name,
    sum(item.quantity)::numeric quantity_sold,sum(item.quantity*item.unit_price)::numeric sales_amount,
    sum(item.quantity*item.unit_cost)::numeric cost_amount,
    sum(item.quantity*(item.unit_price-item.unit_cost))::numeric gross_profit_amount
    FROM public.sales sale JOIN public.sale_items item ON item.sale_id=sale.id
    WHERE sale.restaurant_id=p_restaurant_id AND sale.status='completed'
      AND sale.sale_kind='sale' AND sale.sold_at>=p_from::timestamptz
      AND sale.sold_at<(p_to+1)::timestamptz
    GROUP BY coalesce(item.item_id::text,'name:'||lower(item.product_name)),
      item.product_name,coalesce(nullif(item.category_name,''),'Sin categoria')) row_data), '[]');
END;
$$;

CREATE OR REPLACE FUNCTION public.app_save_product_recipe(
  p_restaurant_id uuid, p_product_id uuid, p_lines jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE line_payload jsonb; canonical_lines jsonb := '[]'::jsonb; position integer := 0;
  reply jsonb;
BEGIN
  FOR line_payload IN SELECT value FROM jsonb_array_elements(coalesce(p_lines,'[]')) LOOP
    canonical_lines := canonical_lines || jsonb_build_array(jsonb_build_object(
      'component_item_id', coalesce(line_payload ->> 'component_item_id',line_payload ->> 'component_product_id',line_payload ->> 'product_id'),
      'unit_id', line_payload ->> 'unit_id', 'quantity', (line_payload ->> 'quantity')::numeric,
      'waste_percent', coalesce((line_payload ->> 'waste_percent')::numeric,0),
      'display_order', position, 'is_active', true));
    position := position + 1;
  END LOOP;
  reply := public.app_save_item_recipe_v2(p_restaurant_id,p_product_id,canonical_lines);
  RETURN coalesce(reply,jsonb_build_object('item_id',p_product_id));
END;
$$;
