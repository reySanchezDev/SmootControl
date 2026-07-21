ALTER TABLE public.cash_register_sessions
  ADD COLUMN IF NOT EXISTS pos_device_id uuid
    REFERENCES public.pos_devices(id) ON DELETE SET NULL;

ALTER TABLE public.sales
  ADD COLUMN IF NOT EXISTS pos_device_id uuid
    REFERENCES public.pos_devices(id) ON DELETE SET NULL;

ALTER TABLE public.operating_expenses
  ADD COLUMN IF NOT EXISTS pos_device_id uuid
    REFERENCES public.pos_devices(id) ON DELETE SET NULL;

ALTER TABLE public.employee_salary_advances
  ADD COLUMN IF NOT EXISTS pos_device_id uuid
    REFERENCES public.pos_devices(id) ON DELETE SET NULL;

ALTER TABLE public.inventory_movements
  ADD COLUMN IF NOT EXISTS pos_device_id uuid
    REFERENCES public.pos_devices(id) ON DELETE SET NULL;

ALTER TABLE public.packaging_movements
  ADD COLUMN IF NOT EXISTS pos_device_id uuid
    REFERENCES public.pos_devices(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS cash_sessions_pos_device_idx
  ON public.cash_register_sessions (restaurant_id, pos_device_id, business_date);

CREATE INDEX IF NOT EXISTS sales_pos_device_idx
  ON public.sales (restaurant_id, pos_device_id, sold_at);

CREATE INDEX IF NOT EXISTS operating_expenses_pos_device_idx
  ON public.operating_expenses (restaurant_id, pos_device_id, spent_at);

CREATE INDEX IF NOT EXISTS salary_advances_pos_device_idx
  ON public.employee_salary_advances (restaurant_id, pos_device_id, delivered_at);

CREATE INDEX IF NOT EXISTS inventory_movements_pos_device_idx
  ON public.inventory_movements (restaurant_id, pos_device_id, created_at);

CREATE INDEX IF NOT EXISTS packaging_movements_pos_device_idx
  ON public.packaging_movements (restaurant_id, pos_device_id, created_at);

ALTER FUNCTION public.pos_sync_cash_register_session(uuid, uuid, text, jsonb)
RENAME TO pos_sync_cash_register_session_device_trace_base_20260717;

CREATE OR REPLACE FUNCTION public.pos_sync_cash_register_session(
  p_restaurant_id uuid,
  p_device_id uuid,
  p_device_secret text,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result jsonb;
  session_id uuid;
BEGIN
  result := public.pos_sync_cash_register_session_device_trace_base_20260717(
    p_restaurant_id,
    p_device_id,
    p_device_secret,
    p_payload
  );

  session_id := COALESCE(
    NULLIF(result ->> 'remote_id', '')::uuid,
    NULLIF(p_payload ->> 'id', '')::uuid
  );

  IF session_id IS NOT NULL THEN
    UPDATE public.cash_register_sessions
       SET pos_device_id = p_device_id
     WHERE id = session_id
       AND restaurant_id = p_restaurant_id;
  END IF;

  RETURN result;
END;
$$;

ALTER FUNCTION public.pos_sync_sale(uuid, uuid, text, jsonb)
RENAME TO pos_sync_sale_device_trace_base_20260717;

CREATE OR REPLACE FUNCTION public.pos_sync_sale(
  p_restaurant_id uuid,
  p_device_id uuid,
  p_device_secret text,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result jsonb;
  sale_id uuid;
BEGIN
  result := public.pos_sync_sale_device_trace_base_20260717(
    p_restaurant_id,
    p_device_id,
    p_device_secret,
    p_payload
  );

  sale_id := NULLIF(result ->> 'remote_id', '')::uuid;
  IF sale_id IS NOT NULL THEN
    UPDATE public.sales
       SET pos_device_id = p_device_id
     WHERE id = sale_id
       AND restaurant_id = p_restaurant_id;

    UPDATE public.inventory_movements
       SET pos_device_id = p_device_id
     WHERE restaurant_id = p_restaurant_id
       AND reference_id = sale_id::text;

    UPDATE public.packaging_movements
       SET pos_device_id = p_device_id
     WHERE restaurant_id = p_restaurant_id
       AND reference_id = sale_id::text;
  END IF;

  RETURN result;
END;
$$;

ALTER FUNCTION public.pos_sync_staff_consumption(uuid, uuid, text, jsonb)
RENAME TO pos_sync_staff_consumption_device_trace_base_20260717;

CREATE OR REPLACE FUNCTION public.pos_sync_staff_consumption(
  p_restaurant_id uuid,
  p_device_id uuid,
  p_device_secret text,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result jsonb;
  sale_id uuid;
BEGIN
  result := public.pos_sync_staff_consumption_device_trace_base_20260717(
    p_restaurant_id,
    p_device_id,
    p_device_secret,
    p_payload
  );

  sale_id := NULLIF(result ->> 'remote_id', '')::uuid;
  IF sale_id IS NOT NULL THEN
    UPDATE public.sales
       SET pos_device_id = p_device_id
     WHERE id = sale_id
       AND restaurant_id = p_restaurant_id;

    UPDATE public.inventory_movements
       SET pos_device_id = p_device_id
     WHERE restaurant_id = p_restaurant_id
       AND reference_id = sale_id::text;

    UPDATE public.packaging_movements
       SET pos_device_id = p_device_id
     WHERE restaurant_id = p_restaurant_id
       AND reference_id = sale_id::text;
  END IF;

  RETURN result;
END;
$$;

ALTER FUNCTION public.pos_sync_operating_expense(uuid, uuid, text, jsonb)
RENAME TO pos_sync_operating_expense_device_trace_base_20260717;

CREATE OR REPLACE FUNCTION public.pos_sync_operating_expense(
  p_restaurant_id uuid,
  p_device_id uuid,
  p_device_secret text,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result jsonb;
  expense_id uuid;
BEGIN
  result := public.pos_sync_operating_expense_device_trace_base_20260717(
    p_restaurant_id,
    p_device_id,
    p_device_secret,
    p_payload
  );

  expense_id := COALESCE(
    NULLIF(result ->> 'remote_id', '')::uuid,
    NULLIF(p_payload ->> 'id', '')::uuid
  );

  IF expense_id IS NOT NULL THEN
    UPDATE public.operating_expenses
       SET pos_device_id = p_device_id
     WHERE id = expense_id
       AND restaurant_id = p_restaurant_id;
  END IF;

  RETURN result;
END;
$$;

ALTER FUNCTION public.pos_sync_salary_advance(uuid, uuid, text, jsonb)
RENAME TO pos_sync_salary_advance_device_trace_base_20260717;

CREATE OR REPLACE FUNCTION public.pos_sync_salary_advance(
  p_restaurant_id uuid,
  p_device_id uuid,
  p_device_secret text,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result jsonb;
  advance_id uuid;
BEGIN
  result := public.pos_sync_salary_advance_device_trace_base_20260717(
    p_restaurant_id,
    p_device_id,
    p_device_secret,
    p_payload
  );

  advance_id := COALESCE(
    NULLIF(result ->> 'remote_id', '')::uuid,
    NULLIF(p_payload ->> 'id', '')::uuid
  );

  IF advance_id IS NOT NULL THEN
    UPDATE public.employee_salary_advances
       SET pos_device_id = p_device_id
     WHERE id = advance_id
       AND restaurant_id = p_restaurant_id;
  END IF;

  RETURN result;
END;
$$;

REVOKE ALL ON FUNCTION public.pos_sync_cash_register_session(
  uuid, uuid, text, jsonb
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pos_sync_sale(uuid, uuid, text, jsonb)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pos_sync_staff_consumption(
  uuid, uuid, text, jsonb
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pos_sync_operating_expense(
  uuid, uuid, text, jsonb
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pos_sync_salary_advance(
  uuid, uuid, text, jsonb
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.pos_sync_cash_register_session(
  uuid, uuid, text, jsonb
) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.pos_sync_sale(uuid, uuid, text, jsonb)
  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.pos_sync_staff_consumption(
  uuid, uuid, text, jsonb
) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.pos_sync_operating_expense(
  uuid, uuid, text, jsonb
) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.pos_sync_salary_advance(
  uuid, uuid, text, jsonb
) TO anon, authenticated, service_role;
