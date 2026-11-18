-- Defense in depth for SECURITY DEFINER RPCs. RLS protects direct REST calls;
-- these triggers also protect writes performed by trusted functions.
CREATE OR REPLACE FUNCTION public.app_require_packaging_actor()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
SET row_security = off
AS $$
DECLARE
  target_restaurant uuid := COALESCE(NEW.restaurant_id, OLD.restaurant_id);
  actor_is_pos boolean;
  has_permission boolean;
BEGIN
  IF auth.role() = 'service_role'
    OR (auth.uid() IS NULL AND auth.role() IS NULL) THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  SELECT p.is_pos_user
    INTO actor_is_pos
  FROM public.profiles AS p
  WHERE p.id = auth.uid()
    AND p.restaurant_id = target_restaurant
    AND p.is_active = true;

  IF actor_is_pos IS NULL THEN
    RAISE EXCEPTION 'Actor no autorizado para el restaurante'
      USING ERRCODE = '42501';
  END IF;

  IF TG_ARGV[0] = 'tipos_venta.gestionar' AND actor_is_pos THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM public.profiles AS actor
    JOIN public.role_permissions AS grant_row
      ON grant_row.role_id = actor.role_id
    JOIN public.permissions AS permission
      ON permission.id = grant_row.permission_id
    WHERE actor.id = auth.uid()
      AND actor.restaurant_id = target_restaurant
      AND actor.is_active = true
      AND actor.is_pos_user = false
      AND permission.code = ANY (TG_ARGV)
  )
    INTO has_permission;

  IF NOT has_permission THEN
    RAISE EXCEPTION 'Permiso insuficiente para modificar el catálogo'
      USING ERRCODE = '42501';
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;

REVOKE ALL ON FUNCTION public.app_require_packaging_actor() FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.validate_product_packaging_rule_tenant()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
SET row_security = off
AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.products
    WHERE id = NEW.product_id AND restaurant_id = NEW.restaurant_id
  ) IS NOT TRUE
  OR EXISTS (
    SELECT 1 FROM public.sales_types
    WHERE id = NEW.sales_type_id AND restaurant_id = NEW.restaurant_id
  ) IS NOT TRUE
  OR EXISTS (
    SELECT 1 FROM public.packaging_items
    WHERE id = NEW.packaging_item_id AND restaurant_id = NEW.restaurant_id
  ) IS NOT TRUE THEN
    RAISE EXCEPTION 'Regla de empaque contiene entidades de otro restaurante'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.validate_product_packaging_rule_tenant()
  FROM PUBLIC;

DROP TRIGGER IF EXISTS sales_types_packaging_actor_guard
  ON public.sales_types;
CREATE TRIGGER sales_types_packaging_actor_guard
BEFORE INSERT OR UPDATE OR DELETE ON public.sales_types
FOR EACH ROW EXECUTE FUNCTION public.app_require_packaging_actor(
  'tipos_venta.gestionar'
);

DROP TRIGGER IF EXISTS packaging_items_actor_guard ON public.packaging_items;
CREATE TRIGGER packaging_items_actor_guard
BEFORE INSERT OR UPDATE OR DELETE ON public.packaging_items
FOR EACH ROW EXECUTE FUNCTION public.app_require_packaging_actor(
  'empaques.gestionar'
);

DROP TRIGGER IF EXISTS packaging_rules_actor_guard
  ON public.product_packaging_rules;
CREATE TRIGGER packaging_rules_actor_guard
BEFORE INSERT OR UPDATE OR DELETE ON public.product_packaging_rules
FOR EACH ROW EXECUTE FUNCTION public.app_require_packaging_actor(
  'empaques.gestionar'
);

DROP TRIGGER IF EXISTS packaging_rule_tenant_guard
  ON public.product_packaging_rules;
CREATE TRIGGER packaging_rule_tenant_guard
BEFORE INSERT OR UPDATE ON public.product_packaging_rules
FOR EACH ROW EXECUTE FUNCTION public.validate_product_packaging_rule_tenant();

DROP TRIGGER IF EXISTS packaging_movements_actor_guard
  ON public.packaging_movements;
CREATE TRIGGER packaging_movements_actor_guard
BEFORE INSERT OR UPDATE OR DELETE ON public.packaging_movements
FOR EACH ROW EXECUTE FUNCTION public.app_require_packaging_actor(
  'empaques.gestionar', 'inventario.gestionar'
);
