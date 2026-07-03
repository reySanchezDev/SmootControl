CREATE OR REPLACE FUNCTION public.pos_pull_operational_catalog(
  p_restaurant_id uuid,
  p_device_id uuid,
  p_device_secret text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.assert_pos_device(
    p_restaurant_id,
    p_device_id,
    p_device_secret
  );

  INSERT INTO public.sales_types (
    restaurant_id,
    code,
    name,
    display_order,
    is_default,
    is_active
  )
  VALUES
    (p_restaurant_id, 'dine_in', 'Comer aqui', 0, true, true),
    (p_restaurant_id, 'to_go', 'Para llevar', 1, false, true)
  ON CONFLICT (restaurant_id, code) DO NOTHING;

  RETURN jsonb_build_object(
    'restaurants', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.restaurants
           WHERE id = p_restaurant_id
        ) row_data
    ), '[]'::jsonb),
    'invoice_number_settings', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.invoice_number_settings
           WHERE restaurant_id = p_restaurant_id
        ) row_data
    ), '[]'::jsonb),
    'permissions', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.permissions
        ) row_data
    ), '[]'::jsonb),
    'roles', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.roles
           WHERE restaurant_id = p_restaurant_id
              OR restaurant_id IS NULL
        ) row_data
    ), '[]'::jsonb),
    'role_permissions', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT role_permission.role_id,
                 role_permission.permission_id
            FROM public.role_permissions role_permission
            JOIN public.roles role_row
              ON role_row.id = role_permission.role_id
           WHERE role_row.restaurant_id = p_restaurant_id
              OR role_row.restaurant_id IS NULL
        ) row_data
    ), '[]'::jsonb),
    'profiles', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.profiles
           WHERE restaurant_id = p_restaurant_id
        ) row_data
    ), '[]'::jsonb),
    'product_categories', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.product_categories
           WHERE restaurant_id = p_restaurant_id
           ORDER BY display_order, name
        ) row_data
    ), '[]'::jsonb),
    'modifier_groups', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.modifier_groups
           WHERE restaurant_id = p_restaurant_id
           ORDER BY display_order, name
        ) row_data
    ), '[]'::jsonb),
    'modifier_options', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.modifier_options
           WHERE restaurant_id = p_restaurant_id
           ORDER BY display_order, name
        ) row_data
    ), '[]'::jsonb),
    'product_modifier_groups', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.product_modifier_groups
           WHERE restaurant_id = p_restaurant_id
           ORDER BY display_order
        ) row_data
    ), '[]'::jsonb),
    'products', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.products
           WHERE restaurant_id = p_restaurant_id
           ORDER BY name
        ) row_data
    ), '[]'::jsonb),
    'inventory_stock', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.inventory_stock
           WHERE restaurant_id = p_restaurant_id
        ) row_data
    ), '[]'::jsonb),
    'sales_types', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.sales_types
           WHERE restaurant_id = p_restaurant_id
           ORDER BY display_order, name
        ) row_data
    ), '[]'::jsonb),
    'packaging_items', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.packaging_items
           WHERE restaurant_id = p_restaurant_id
           ORDER BY name
        ) row_data
    ), '[]'::jsonb),
    'product_packaging_rules', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.product_packaging_rules
           WHERE restaurant_id = p_restaurant_id
           ORDER BY product_id, sales_type_id
        ) row_data
    ), '[]'::jsonb),
    'packaging_stock', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.packaging_stock
           WHERE restaurant_id = p_restaurant_id
        ) row_data
    ), '[]'::jsonb),
    'payment_methods', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.payment_methods
           WHERE restaurant_id = p_restaurant_id
              OR restaurant_id IS NULL
           ORDER BY display_order, name
        ) row_data
    ), '[]'::jsonb),
    'restaurant_tables', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.restaurant_tables
           WHERE restaurant_id = p_restaurant_id
           ORDER BY name
        ) row_data
    ), '[]'::jsonb),
    'expense_categories', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.expense_categories
           WHERE restaurant_id = p_restaurant_id
              OR restaurant_id IS NULL
           ORDER BY name
        ) row_data
    ), '[]'::jsonb),
    'exchange_rates', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.exchange_rates
           WHERE restaurant_id = p_restaurant_id
           ORDER BY business_date DESC, currency_code
        ) row_data
    ), '[]'::jsonb),
    'cash_register_sessions', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.cash_register_sessions
           WHERE restaurant_id = p_restaurant_id
        ) row_data
    ), '[]'::jsonb)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.pos_pull_operational_catalog(
  uuid,
  uuid,
  text
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.pos_pull_operational_catalog(
  uuid,
  uuid,
  text
) TO anon, authenticated;
