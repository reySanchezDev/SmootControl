-- Separate catalog reading (same restaurant) from permission-gated writes.
-- The original FOR ALL policies permitted any authenticated tenant member
-- to modify catalog data. Keep SELECT accessible for POS/catalog consumers.
-- Do not change packaging_stock / packaging_movements or POS RPC privileges.
CREATE OR REPLACE FUNCTION public.app_can_manage_packaging_catalog(
  p_restaurant_id uuid,
  p_permission_code text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT auth.uid() IS NOT NULL
    AND public.is_same_restaurant(p_restaurant_id)
    AND p_permission_code IN (
      'tipos_venta.gestionar', 'empaques.gestionar'
    )
    AND EXISTS (
      SELECT 1
      FROM public.profiles AS actor
      JOIN public.role_permissions AS grant_row
        ON grant_row.role_id = actor.role_id
      JOIN public.permissions AS permission
        ON permission.id = grant_row.permission_id
      WHERE actor.id = auth.uid()
        AND actor.restaurant_id = p_restaurant_id
        AND actor.is_active = true
        AND actor.is_pos_user = false
        AND permission.code = p_permission_code
    );
$$;

REVOKE ALL ON FUNCTION public.app_can_manage_packaging_catalog(uuid, text)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.app_can_manage_packaging_catalog(uuid, text)
  TO authenticated;

DROP POLICY IF EXISTS sales_types_same_restaurant ON public.sales_types;
DROP POLICY IF EXISTS sales_types_catalog_read ON public.sales_types;
DROP POLICY IF EXISTS sales_types_catalog_insert ON public.sales_types;
DROP POLICY IF EXISTS sales_types_catalog_update ON public.sales_types;
DROP POLICY IF EXISTS sales_types_catalog_delete ON public.sales_types;

CREATE POLICY sales_types_catalog_read ON public.sales_types
FOR SELECT TO authenticated
USING (public.is_same_restaurant(restaurant_id));

CREATE POLICY sales_types_catalog_insert ON public.sales_types
FOR INSERT TO authenticated
WITH CHECK (public.app_can_manage_packaging_catalog(
  restaurant_id, 'tipos_venta.gestionar'
));

CREATE POLICY sales_types_catalog_update ON public.sales_types
FOR UPDATE TO authenticated
USING (public.app_can_manage_packaging_catalog(
  restaurant_id, 'tipos_venta.gestionar'
))
WITH CHECK (public.app_can_manage_packaging_catalog(
  restaurant_id, 'tipos_venta.gestionar'
));

CREATE POLICY sales_types_catalog_delete ON public.sales_types
FOR DELETE TO authenticated
USING (public.app_can_manage_packaging_catalog(
  restaurant_id, 'tipos_venta.gestionar'
));

DROP POLICY IF EXISTS packaging_items_same_restaurant ON public.packaging_items;
DROP POLICY IF EXISTS packaging_items_catalog_read ON public.packaging_items;
DROP POLICY IF EXISTS packaging_items_catalog_insert ON public.packaging_items;
DROP POLICY IF EXISTS packaging_items_catalog_update ON public.packaging_items;
DROP POLICY IF EXISTS packaging_items_catalog_delete ON public.packaging_items;

CREATE POLICY packaging_items_catalog_read ON public.packaging_items
FOR SELECT TO authenticated
USING (public.is_same_restaurant(restaurant_id));

CREATE POLICY packaging_items_catalog_insert ON public.packaging_items
FOR INSERT TO authenticated
WITH CHECK (public.app_can_manage_packaging_catalog(
  restaurant_id, 'empaques.gestionar'
));

CREATE POLICY packaging_items_catalog_update ON public.packaging_items
FOR UPDATE TO authenticated
USING (public.app_can_manage_packaging_catalog(
  restaurant_id, 'empaques.gestionar'
))
WITH CHECK (public.app_can_manage_packaging_catalog(
  restaurant_id, 'empaques.gestionar'
));

CREATE POLICY packaging_items_catalog_delete ON public.packaging_items
FOR DELETE TO authenticated
USING (public.app_can_manage_packaging_catalog(
  restaurant_id, 'empaques.gestionar'
));

DROP POLICY IF EXISTS product_packaging_rules_same_restaurant
  ON public.product_packaging_rules;
DROP POLICY IF EXISTS product_packaging_rules_catalog_read
  ON public.product_packaging_rules;
DROP POLICY IF EXISTS product_packaging_rules_catalog_insert
  ON public.product_packaging_rules;
DROP POLICY IF EXISTS product_packaging_rules_catalog_update
  ON public.product_packaging_rules;
DROP POLICY IF EXISTS product_packaging_rules_catalog_delete
  ON public.product_packaging_rules;

CREATE POLICY product_packaging_rules_catalog_read
ON public.product_packaging_rules
FOR SELECT TO authenticated
USING (public.is_same_restaurant(restaurant_id));

CREATE POLICY product_packaging_rules_catalog_insert
ON public.product_packaging_rules
FOR INSERT TO authenticated
WITH CHECK (public.app_can_manage_packaging_catalog(
  restaurant_id, 'empaques.gestionar'
));

CREATE POLICY product_packaging_rules_catalog_update
ON public.product_packaging_rules
FOR UPDATE TO authenticated
USING (public.app_can_manage_packaging_catalog(
  restaurant_id, 'empaques.gestionar'
))
WITH CHECK (public.app_can_manage_packaging_catalog(
  restaurant_id, 'empaques.gestionar'
));

CREATE POLICY product_packaging_rules_catalog_delete
ON public.product_packaging_rules
FOR DELETE TO authenticated
USING (public.app_can_manage_packaging_catalog(
  restaurant_id, 'empaques.gestionar'
));

COMMENT ON FUNCTION public.app_can_manage_packaging_catalog(uuid, text)
IS 'Returns true only for an active Backoffice actor with the catalog permission in the same restaurant.';
