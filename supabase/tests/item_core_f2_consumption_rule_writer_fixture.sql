-- Synthetic authorization fixture for the revision handshake only.
-- Full F1 role/JWT security must be retested in G2 on the actual schema.
ALTER TABLE public.item_consumption_rules
  ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now();

CREATE OR REPLACE FUNCTION public.app_assert_admin_permission(
  p_restaurant_id uuid,p_permission text
) RETURNS void LANGUAGE plpgsql
AS $$
BEGIN
  IF p_restaurant_id <>
       '00000000-0000-0000-0000-000000000001'::uuid
     OR p_permission<>'reglas_consumo.gestionar'
     OR current_setting('app.can_write_rule',true)<>'true' THEN
    RAISE EXCEPTION 'rule_permission_denied' USING ERRCODE='42501';
  END IF;
END;
$$;

INSERT INTO public.item_catalog_revisions(restaurant_id)
VALUES('00000000-0000-0000-0000-000000000001');
SELECT set_config('app.can_write_rule','true',true);
