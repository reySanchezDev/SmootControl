-- Canonical item-to-modifier assignment.
BEGIN;

CREATE TABLE IF NOT EXISTS public.item_modifier_groups (
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  item_id uuid NOT NULL,
  modifier_group_id uuid NOT NULL REFERENCES public.modifier_groups(id) ON DELETE CASCADE,
  display_order integer NOT NULL DEFAULT 0,
  PRIMARY KEY (restaurant_id, item_id, modifier_group_id),
  FOREIGN KEY (restaurant_id, item_id) REFERENCES public.items(restaurant_id, id)
    ON DELETE CASCADE
);

INSERT INTO public.item_modifier_groups(restaurant_id,item_id,modifier_group_id,display_order)
SELECT legacy.restaurant_id, legacy.product_id, legacy.modifier_group_id, legacy.display_order
FROM public.product_modifier_groups legacy
JOIN public.items item ON item.id=legacy.product_id AND item.restaurant_id=legacy.restaurant_id
ON CONFLICT DO NOTHING;

ALTER TABLE public.item_modifier_groups ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS item_modifier_groups_tenant_read ON public.item_modifier_groups;
CREATE POLICY item_modifier_groups_tenant_read ON public.item_modifier_groups
  FOR SELECT TO authenticated USING (restaurant_id = public.current_restaurant_id());
REVOKE ALL ON public.item_modifier_groups FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.item_modifier_groups TO authenticated;

CREATE OR REPLACE FUNCTION public.app_set_item_modifier_groups_v2(
  p_restaurant_id uuid, p_item_id uuid, p_group_ids jsonb
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE group_id uuid; position integer := 0;
BEGIN
  PERFORM public.app_assert_admin_permission(p_restaurant_id, 'productos.gestionar');
  IF NOT EXISTS (SELECT 1 FROM public.items WHERE id=p_item_id
    AND restaurant_id=p_restaurant_id) THEN RAISE EXCEPTION 'Artículo invalido'; END IF;
  DELETE FROM public.item_modifier_groups
    WHERE restaurant_id=p_restaurant_id AND item_id=p_item_id;
  FOR group_id IN SELECT value::text::uuid FROM jsonb_array_elements_text(coalesce(p_group_ids,'[]')) LOOP
    INSERT INTO public.item_modifier_groups(restaurant_id,item_id,modifier_group_id,display_order)
    VALUES (p_restaurant_id,p_item_id,group_id,position);
    position := position + 1;
  END LOOP;
  PERFORM item_core_internal.bump_item_catalog_revision(p_restaurant_id);
END;
$$;
REVOKE ALL ON FUNCTION public.app_set_item_modifier_groups_v2(uuid,uuid,jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_set_item_modifier_groups_v2(uuid,uuid,jsonb) TO authenticated;
COMMIT;
