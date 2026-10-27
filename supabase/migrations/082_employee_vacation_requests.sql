-- Vacation requests and balance report for staff.

INSERT INTO public.permissions (code, name)
VALUES
  ('vacaciones.ver', 'Ver vacaciones'),
  ('vacaciones.gestionar', 'Gestionar vacaciones'),
  ('vacaciones.solicitar', 'Solicitar vacaciones'),
  ('reportes.vacaciones.ver', 'Ver reporte de vacaciones')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT role.id, permission.id
  FROM public.roles role
 CROSS JOIN public.permissions permission
 WHERE role.code = 'admin'
   AND permission.code IN (
     'vacaciones.ver',
     'vacaciones.gestionar',
     'vacaciones.solicitar',
     'reportes.vacaciones.ver'
   )
ON CONFLICT DO NOTHING;

ALTER TABLE public.employees
  ADD COLUMN IF NOT EXISTS vacation_accrual_start_date date;

UPDATE public.employees
   SET vacation_accrual_start_date = created_at::date
 WHERE vacation_accrual_start_date IS NULL;

INSERT INTO public.business_rules (restaurant_id, key, text_value)
SELECT restaurant.id, 'vacation_days_per_month', '2.5'
  FROM public.restaurants restaurant
ON CONFLICT (restaurant_id, key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.employee_vacation_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  local_id text,
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  employee_id uuid NOT NULL REFERENCES public.employees(id),
  pos_device_id uuid REFERENCES public.pos_devices(id),
  start_date date NOT NULL,
  end_date date NOT NULL,
  requested_days numeric(8, 2) NOT NULL CHECK (requested_days > 0),
  request_type text NOT NULL DEFAULT 'planned'
    CHECK (request_type IN ('planned', 'taken')),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
  source text NOT NULL DEFAULT 'admin'
    CHECK (source IN ('admin', 'time_clock')),
  note text,
  created_by_user_id uuid REFERENCES auth.users(id),
  approved_by_user_id uuid REFERENCES auth.users(id),
  approved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (restaurant_id, local_id),
  CHECK (end_date >= start_date)
);

CREATE INDEX IF NOT EXISTS employee_vacation_requests_restaurant_date_idx
  ON public.employee_vacation_requests (restaurant_id, start_date DESC);

CREATE INDEX IF NOT EXISTS employee_vacation_requests_employee_status_idx
  ON public.employee_vacation_requests (employee_id, status, start_date);

ALTER TABLE public.employee_vacation_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS employee_vacation_requests_same_restaurant
  ON public.employee_vacation_requests;
CREATE POLICY employee_vacation_requests_same_restaurant
  ON public.employee_vacation_requests
  FOR ALL TO authenticated
  USING (public.is_same_restaurant(restaurant_id))
  WITH CHECK (public.is_same_restaurant(restaurant_id));

CREATE OR REPLACE FUNCTION public.app_save_employee_vacation_request(
  p_restaurant_id uuid,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  request_id uuid;
  employee_id_value uuid;
  start_date_value date;
  end_date_value date;
  days_value numeric(8, 2);
  status_value text;
  result_row jsonb;
BEGIN
  PERFORM public.app_assert_admin_permission(p_restaurant_id, 'vacaciones.gestionar');

  request_id := NULLIF(btrim(COALESCE(p_payload ->> 'id', '')), '')::uuid;
  request_id := COALESCE(request_id, gen_random_uuid());
  employee_id_value := (p_payload ->> 'employee_id')::uuid;
  start_date_value := (p_payload ->> 'start_date')::date;
  end_date_value := (p_payload ->> 'end_date')::date;
  days_value := COALESCE(
    NULLIF(p_payload ->> 'requested_days', '')::numeric,
    (end_date_value - start_date_value + 1)::numeric
  );
  status_value := COALESCE(NULLIF(p_payload ->> 'status', ''), 'approved');

  IF NOT EXISTS (
    SELECT 1 FROM public.employees
     WHERE id = employee_id_value
       AND restaurant_id = p_restaurant_id
       AND is_active = true
  ) THEN
    RAISE EXCEPTION 'Empleado invalido para vacaciones';
  END IF;

  INSERT INTO public.employee_vacation_requests (
    id, restaurant_id, employee_id, start_date, end_date, requested_days,
    request_type, status, source, note, created_by_user_id,
    approved_by_user_id, approved_at, updated_at
  )
  VALUES (
    request_id, p_restaurant_id, employee_id_value, start_date_value,
    end_date_value, days_value,
    COALESCE(NULLIF(p_payload ->> 'request_type', ''), 'planned'),
    status_value,
    'admin',
    NULLIF(p_payload ->> 'note', ''),
    auth.uid(),
    CASE WHEN status_value = 'approved' THEN auth.uid() ELSE NULL END,
    CASE WHEN status_value = 'approved' THEN now() ELSE NULL END,
    now()
  )
  ON CONFLICT (id) DO UPDATE
     SET employee_id = EXCLUDED.employee_id,
         start_date = EXCLUDED.start_date,
         end_date = EXCLUDED.end_date,
         requested_days = EXCLUDED.requested_days,
         request_type = EXCLUDED.request_type,
         status = EXCLUDED.status,
         note = EXCLUDED.note,
         approved_by_user_id = CASE
           WHEN EXCLUDED.status = 'approved'
           THEN COALESCE(employee_vacation_requests.approved_by_user_id, auth.uid())
           ELSE employee_vacation_requests.approved_by_user_id
         END,
         approved_at = CASE
           WHEN EXCLUDED.status = 'approved'
           THEN COALESCE(employee_vacation_requests.approved_at, now())
           ELSE employee_vacation_requests.approved_at
         END,
         updated_at = now()
   WHERE employee_vacation_requests.restaurant_id = p_restaurant_id
  RETURNING jsonb_build_object('id', employee_vacation_requests.id)
    INTO result_row;

  RETURN result_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.pos_sync_employee_vacation_request(
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
  request_id uuid;
  employee_id_value uuid;
  start_date_value date;
  end_date_value date;
  days_value numeric(8, 2);
BEGIN
  PERFORM public.assert_pos_device(p_restaurant_id, p_device_id, p_device_secret);

  request_id := (p_payload ->> 'id')::uuid;
  employee_id_value := (p_payload ->> 'employee_id')::uuid;
  start_date_value := (p_payload ->> 'start_date')::date;
  end_date_value := (p_payload ->> 'end_date')::date;
  days_value := COALESCE(
    NULLIF(p_payload ->> 'requested_days', '')::numeric,
    (end_date_value - start_date_value + 1)::numeric
  );

  IF NOT EXISTS (
    SELECT 1 FROM public.employees
     WHERE id = employee_id_value
       AND restaurant_id = p_restaurant_id
       AND is_active = true
       AND show_in_time_clock = true
  ) THEN
    RAISE EXCEPTION 'Empleado no habilitado para solicitar vacaciones';
  END IF;

  INSERT INTO public.employee_vacation_requests (
    id, local_id, restaurant_id, employee_id, pos_device_id, start_date,
    end_date, requested_days, request_type, status, source, note, created_at,
    updated_at
  )
  VALUES (
    request_id,
    p_payload ->> 'local_id',
    p_restaurant_id,
    employee_id_value,
    p_device_id,
    start_date_value,
    end_date_value,
    days_value,
    COALESCE(NULLIF(p_payload ->> 'request_type', ''), 'planned'),
    'pending',
    'time_clock',
    NULLIF(p_payload ->> 'note', ''),
    COALESCE(NULLIF(p_payload ->> 'created_at', '')::timestamptz, now()),
    now()
  )
  ON CONFLICT (restaurant_id, local_id) DO UPDATE
     SET start_date = EXCLUDED.start_date,
         end_date = EXCLUDED.end_date,
         requested_days = EXCLUDED.requested_days,
         request_type = EXCLUDED.request_type,
         note = EXCLUDED.note,
         updated_at = now()
   WHERE employee_vacation_requests.status = 'pending';

  RETURN jsonb_build_object('id', request_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_set_employee_vacation_status(
  p_restaurant_id uuid,
  p_request_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.app_assert_admin_permission(p_restaurant_id, 'vacaciones.gestionar');

  IF p_status NOT IN ('approved', 'rejected', 'cancelled') THEN
    RAISE EXCEPTION 'Estado de vacaciones invalido';
  END IF;

  UPDATE public.employee_vacation_requests
     SET status = p_status,
         approved_by_user_id = CASE WHEN p_status = 'approved' THEN auth.uid() ELSE approved_by_user_id END,
         approved_at = CASE WHEN p_status = 'approved' THEN now() ELSE approved_at END,
         updated_at = now()
   WHERE id = p_request_id
     AND restaurant_id = p_restaurant_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.app_delete_employee_vacation_request(
  p_restaurant_id uuid,
  p_request_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.app_assert_admin_permission(p_restaurant_id, 'vacaciones.gestionar');

  DELETE FROM public.employee_vacation_requests
   WHERE id = p_request_id
     AND restaurant_id = p_restaurant_id;
END;
$$;

REVOKE ALL ON FUNCTION public.app_save_employee_vacation_request(uuid, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pos_sync_employee_vacation_request(uuid, uuid, text, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.app_set_employee_vacation_status(uuid, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.app_delete_employee_vacation_request(uuid, uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.app_save_employee_vacation_request(uuid, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pos_sync_employee_vacation_request(uuid, uuid, text, jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_set_employee_vacation_status(uuid, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_delete_employee_vacation_request(uuid, uuid) TO authenticated;
