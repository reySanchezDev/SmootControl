-- Rebuild the device catalog endpoint from current tenant-scoped masters.
-- Compatibility JSON aliases below are projections from items, not legacy
-- table/function dependencies; older installed clients can still deserialize.
BEGIN;

CREATE OR REPLACE FUNCTION public.pos_pull_operational_catalog(
  p_restaurant_id uuid,
  p_device_id uuid,
  p_device_secret text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  PERFORM public.assert_pos_device(
    p_restaurant_id, p_device_id, p_device_secret
  );

  INSERT INTO public.sales_types(
    restaurant_id, code, name, display_order, is_default, is_active
  ) VALUES
    (p_restaurant_id, 'dine_in', 'Comer aqui', 0, true, true),
    (p_restaurant_id, 'to_go', 'Para llevar', 1, false, true)
  ON CONFLICT (restaurant_id, code) DO NOTHING;

  INSERT INTO public.business_rules(restaurant_id, key, bool_value)
  VALUES (p_restaurant_id, 'salary_advance_pos_affects_cash', false)
  ON CONFLICT (restaurant_id, key) DO NOTHING;

  RETURN jsonb_build_object(
    'restaurants', COALESCE((
      SELECT jsonb_agg(to_jsonb(r)) FROM public.restaurants r
      WHERE r.id = p_restaurant_id
    ), '[]'::jsonb),
    'invoice_number_settings', COALESCE((
      SELECT jsonb_agg(to_jsonb(s)) FROM public.invoice_number_settings s
      WHERE s.restaurant_id = p_restaurant_id
    ), '[]'::jsonb),
    'permissions', COALESCE((
      SELECT jsonb_agg(to_jsonb(p)) FROM public.permissions p
    ), '[]'::jsonb),
    'roles', COALESCE((
      SELECT jsonb_agg(to_jsonb(r)) FROM public.roles r
      WHERE r.restaurant_id = p_restaurant_id OR r.restaurant_id IS NULL
    ), '[]'::jsonb),
    'role_permissions', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'role_id', rp.role_id, 'permission_id', rp.permission_id
      ))
      FROM public.role_permissions rp
      JOIN public.roles r ON r.id = rp.role_id
      WHERE r.restaurant_id = p_restaurant_id OR r.restaurant_id IS NULL
    ), '[]'::jsonb),
    'profiles', COALESCE((
      SELECT jsonb_agg(to_jsonb(p)) FROM public.profiles p
      WHERE p.restaurant_id = p_restaurant_id
    ), '[]'::jsonb),
    'product_categories', COALESCE((
      SELECT jsonb_agg(to_jsonb(c) ORDER BY c.display_order, c.name)
      FROM public.product_categories c
      WHERE c.restaurant_id = p_restaurant_id
    ), '[]'::jsonb),
    'modifier_groups', COALESCE((
      SELECT jsonb_agg(to_jsonb(g) ORDER BY g.display_order, g.name)
      FROM public.modifier_groups g
      WHERE g.restaurant_id = p_restaurant_id
    ), '[]'::jsonb),
    'modifier_options', COALESCE((
      SELECT jsonb_agg(to_jsonb(o) ORDER BY o.display_order, o.name)
      FROM public.modifier_options o
      WHERE o.restaurant_id = p_restaurant_id
    ), '[]'::jsonb),
    'item_modifier_groups', COALESCE((
      SELECT jsonb_agg(to_jsonb(g) ORDER BY g.item_id, g.display_order)
      FROM public.item_modifier_groups g
      WHERE g.restaurant_id = p_restaurant_id
    ), '[]'::jsonb),
    'product_modifier_groups', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'item_id', g.item_id, 'product_id', g.item_id,
        'modifier_group_id', g.modifier_group_id,
        'display_order', g.display_order
      ) ORDER BY g.item_id, g.display_order)
      FROM public.item_modifier_groups g
      WHERE g.restaurant_id = p_restaurant_id
    ), '[]'::jsonb),
    'items', COALESCE((
      SELECT jsonb_agg(to_jsonb(i) ORDER BY i.code, i.id)
      FROM public.items i WHERE i.restaurant_id = p_restaurant_id
    ), '[]'::jsonb),
    'products', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', i.id, 'restaurant_id', i.restaurant_id,
        'category_id', i.category_id, 'code', i.code, 'name', i.name,
        'price', i.base_unit_price, 'cost', i.base_unit_cost,
        'is_raw_material', i.item_class = 'raw_material',
        'tracks_inventory', i.tracks_inventory,
        'is_available_in_pos', i.visible_in_pos,
        'is_active', i.is_active
      ) ORDER BY i.code, i.id)
      FROM public.items i
      WHERE i.restaurant_id = p_restaurant_id
        AND i.item_class IN ('sale_product', 'raw_material')
    ), '[]'::jsonb),
    'inventory_stock', COALESCE((
      SELECT jsonb_agg(to_jsonb(s)) FROM public.inventory_stock s
      WHERE s.restaurant_id = p_restaurant_id
    ), '[]'::jsonb),
    'sales_types', COALESCE((
      SELECT jsonb_agg(to_jsonb(s) ORDER BY s.display_order, s.name)
      FROM public.sales_types s WHERE s.restaurant_id = p_restaurant_id
    ), '[]'::jsonb),
    'packaging_items', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', i.id, 'restaurant_id', i.restaurant_id, 'name', i.name,
        'cost', COALESCE(i.base_unit_cost, i.unit_cost),
        'tracks_stock', i.tracks_inventory, 'is_active', i.is_active
      ) ORDER BY i.name, i.id)
      FROM public.items i
      WHERE i.restaurant_id = p_restaurant_id
        AND i.item_class = 'packaging' AND i.is_active
    ), '[]'::jsonb),
    'item_consumption_rules', COALESCE((
      SELECT jsonb_agg(to_jsonb(r) ORDER BY r.id)
      FROM public.item_consumption_rules r
      WHERE r.restaurant_id = p_restaurant_id AND r.is_active
    ), '[]'::jsonb),
    'product_packaging_rules', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', r.id, 'restaurant_id', r.restaurant_id,
        'product_id', r.source_item_id, 'source_item_id', r.source_item_id,
        'packaging_item_id', r.consumed_item_id,
        'consumed_item_id', r.consumed_item_id,
        'sales_type_id', r.sales_type_id,
        'quantity_per_unit', r.quantity, 'quantity', r.quantity,
        'is_active', r.is_active
      ) ORDER BY r.id)
      FROM public.item_consumption_rules r
      JOIN public.items consumed
        ON consumed.id = r.consumed_item_id
       AND consumed.restaurant_id = r.restaurant_id
      WHERE r.restaurant_id = p_restaurant_id AND r.is_active
        AND consumed.item_class = 'packaging'
    ), '[]'::jsonb),
    'packaging_stock', COALESCE((
      SELECT jsonb_agg(to_jsonb(s)) FROM public.packaging_stock s
      WHERE s.restaurant_id = p_restaurant_id
    ), '[]'::jsonb),
    'payment_methods', COALESCE((
      SELECT jsonb_agg(to_jsonb(m) ORDER BY m.display_order, m.name)
      FROM public.payment_methods m
      WHERE m.restaurant_id = p_restaurant_id OR m.restaurant_id IS NULL
    ), '[]'::jsonb),
    'restaurant_tables', COALESCE((
      SELECT jsonb_agg(to_jsonb(t) ORDER BY t.name)
      FROM public.restaurant_tables t
      WHERE t.restaurant_id = p_restaurant_id
    ), '[]'::jsonb),
    'expense_categories', COALESCE((
      SELECT jsonb_agg(to_jsonb(c) ORDER BY c.name)
      FROM public.expense_categories c
      WHERE c.restaurant_id = p_restaurant_id OR c.restaurant_id IS NULL
    ), '[]'::jsonb),
    'exchange_rates', COALESCE((
      SELECT jsonb_agg(to_jsonb(r) ORDER BY r.business_date DESC, r.currency_code)
      FROM public.exchange_rates r WHERE r.restaurant_id = p_restaurant_id
    ), '[]'::jsonb),
    'cash_register_sessions', COALESCE((
      SELECT jsonb_agg(to_jsonb(s)) FROM public.cash_register_sessions s
      WHERE s.restaurant_id = p_restaurant_id
    ), '[]'::jsonb),
    'employees', COALESCE((
      SELECT jsonb_agg(to_jsonb(e) ORDER BY e.full_name)
      FROM public.employees e
      WHERE e.restaurant_id = p_restaurant_id AND e.is_active
    ), '[]'::jsonb),
    'business_rules', COALESCE((
      SELECT jsonb_agg(to_jsonb(r) ORDER BY r.key)
      FROM public.business_rules r WHERE r.restaurant_id = p_restaurant_id
    ), '[]'::jsonb),
    'item_catalog_v2', public.pos_pull_item_catalog_v2(
      p_restaurant_id, p_device_id, p_device_secret
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.pos_pull_operational_catalog(uuid, uuid, text)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pos_pull_operational_catalog(uuid, uuid, text)
  TO anon, authenticated, service_role;

COMMENT ON FUNCTION public.pos_pull_operational_catalog(uuid, uuid, text)
IS 'Device-authenticated operational catalog assembled from current tenant-scoped tables and canonical items; compatibility JSON aliases do not read legacy tables.';

COMMIT;
