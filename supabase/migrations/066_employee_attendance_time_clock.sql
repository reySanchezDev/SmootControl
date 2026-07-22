INSERT INTO public.permissions (code, name)
VALUES
  ('marcadas.ver', 'Ver marcadas'),
  ('marcadas.gestionar', 'Gestionar marcadas'),
  ('horas_extra.autorizar', 'Autorizar horas extra'),
  ('reportes.marcadas.ver', 'Ver reporte de marcadas')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT role.id, permission.id
  FROM public.roles role
  JOIN public.permissions permission
    ON permission.code IN (
      'marcadas.ver',
      'marcadas.gestionar',
      'horas_extra.autorizar',
      'reportes.marcadas.ver'
    )
 WHERE role.code = 'admin'
ON CONFLICT DO NOTHING;

ALTER TABLE public.employees
  ADD COLUMN IF NOT EXISTS photo_url text;

ALTER TABLE public.employees
  ADD COLUMN IF NOT EXISTS show_in_time_clock boolean NOT NULL DEFAULT true;

ALTER TABLE public.pos_devices
  ADD COLUMN IF NOT EXISTS device_purpose text NOT NULL DEFAULT 'pos';

CREATE OR REPLACE FUNCTION public.app_save_employee(
  p_restaurant_id uuid,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  employee_id uuid;
  employee_number_value bigint;
  position_id_value uuid;
  result_row jsonb;
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'personal.gestionar'
  );

  employee_id := NULLIF(btrim(COALESCE(p_payload ->> 'id', '')), '')::uuid;
  position_id_value := NULLIF(
    btrim(COALESCE(p_payload ->> 'position_id', '')),
    ''
  )::uuid;

  IF position_id_value IS NOT NULL AND NOT EXISTS (
    SELECT 1
      FROM public.employee_positions
     WHERE id = position_id_value
       AND restaurant_id = p_restaurant_id
  ) THEN
    RAISE EXCEPTION 'Puesto no pertenece al restaurante';
  END IF;

  IF employee_id IS NULL THEN
    INSERT INTO public.employee_number_settings (restaurant_id, next_number)
    VALUES (p_restaurant_id, 1)
    ON CONFLICT (restaurant_id) DO NOTHING;

    SELECT next_number
      INTO employee_number_value
      FROM public.employee_number_settings
     WHERE restaurant_id = p_restaurant_id
     FOR UPDATE;

    UPDATE public.employee_number_settings
       SET next_number = employee_number_value + 1,
           updated_at = now()
     WHERE restaurant_id = p_restaurant_id;

    employee_id := gen_random_uuid();

    INSERT INTO public.employees (
      id, restaurant_id, employee_number, code, full_name, position_id,
      position_name, base_salary, is_active, photo_url, show_in_time_clock,
      updated_at
    )
    VALUES (
      employee_id, p_restaurant_id, employee_number_value,
      employee_number_value::text, NULLIF(btrim(p_payload ->> 'full_name'), ''),
      position_id_value,
      (SELECT name FROM public.employee_positions WHERE id = position_id_value),
      COALESCE((p_payload ->> 'base_salary')::numeric, 0),
      COALESCE((p_payload ->> 'is_active')::boolean, true),
      NULLIF(btrim(COALESCE(p_payload ->> 'photo_url', '')), ''),
      COALESCE((p_payload ->> 'show_in_time_clock')::boolean, true),
      now()
    );
  ELSE
    UPDATE public.employees
       SET full_name = NULLIF(btrim(p_payload ->> 'full_name'), ''),
           position_id = position_id_value,
           position_name = (
             SELECT name
               FROM public.employee_positions
              WHERE id = position_id_value
           ),
           base_salary = COALESCE((p_payload ->> 'base_salary')::numeric, 0),
           is_active = COALESCE((p_payload ->> 'is_active')::boolean, true),
           photo_url = NULLIF(btrim(COALESCE(p_payload ->> 'photo_url', '')), ''),
           show_in_time_clock =
             COALESCE((p_payload ->> 'show_in_time_clock')::boolean, true),
           updated_at = now()
     WHERE id = employee_id
       AND restaurant_id = p_restaurant_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Empleado no pertenece al restaurante';
    END IF;
  END IF;

  SELECT to_jsonb(employee_row)
    INTO result_row
    FROM public.employees employee_row
   WHERE employee_row.id = employee_id;

  RETURN result_row;
END;
$$;

CREATE TABLE IF NOT EXISTS public.employee_attendance_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  local_id text,
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  employee_id uuid NOT NULL REFERENCES public.employees(id),
  pos_device_id uuid REFERENCES public.pos_devices(id) ON DELETE SET NULL,
  work_date date NOT NULL,
  clock_in_at timestamptz,
  clock_out_at timestamptz,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'closed', 'voided')),
  source text NOT NULL DEFAULT 'time_clock'
    CHECK (source IN ('time_clock', 'admin')),
  verification_method text NOT NULL DEFAULT 'photo_tap',
  note text,
  created_by_user_id uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (restaurant_id, local_id)
);

CREATE INDEX IF NOT EXISTS employee_attendance_entries_restaurant_date_idx
  ON public.employee_attendance_entries (restaurant_id, work_date DESC);

CREATE INDEX IF NOT EXISTS employee_attendance_entries_employee_status_idx
  ON public.employee_attendance_entries (employee_id, status, work_date);

ALTER TABLE public.employee_attendance_entries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS employee_attendance_entries_same_restaurant
  ON public.employee_attendance_entries;
CREATE POLICY employee_attendance_entries_same_restaurant
  ON public.employee_attendance_entries
  FOR ALL TO authenticated
  USING (public.is_same_restaurant(restaurant_id))
  WITH CHECK (public.is_same_restaurant(restaurant_id));

CREATE TABLE IF NOT EXISTS public.employee_overtime_candidates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  attendance_entry_id uuid NOT NULL
    REFERENCES public.employee_attendance_entries(id) ON DELETE CASCADE,
  employee_id uuid NOT NULL REFERENCES public.employees(id),
  worked_date date NOT NULL,
  hours numeric(10, 2) NOT NULL CHECK (hours > 0),
  hour_rate numeric(15, 4) NOT NULL CHECK (hour_rate >= 0),
  total_amount numeric(15, 4) NOT NULL CHECK (total_amount >= 0),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected')),
  overtime_entry_id uuid REFERENCES public.employee_overtime_entries(id)
    ON DELETE SET NULL,
  note text,
  approved_by_user_id uuid REFERENCES auth.users(id),
  approved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (attendance_entry_id)
);

CREATE INDEX IF NOT EXISTS employee_overtime_candidates_restaurant_date_idx
  ON public.employee_overtime_candidates (restaurant_id, worked_date DESC);

ALTER TABLE public.employee_overtime_candidates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS employee_overtime_candidates_same_restaurant
  ON public.employee_overtime_candidates;
CREATE POLICY employee_overtime_candidates_same_restaurant
  ON public.employee_overtime_candidates
  FOR ALL TO authenticated
  USING (public.is_same_restaurant(restaurant_id))
  WITH CHECK (public.is_same_restaurant(restaurant_id));

CREATE OR REPLACE FUNCTION public.app_rebuild_overtime_candidate(
  p_attendance_entry_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  entry_row public.employee_attendance_entries%ROWTYPE;
  worked_hours numeric;
  overtime_hours numeric;
  rate_value numeric;
BEGIN
  SELECT *
    INTO entry_row
    FROM public.employee_attendance_entries
   WHERE id = p_attendance_entry_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  IF entry_row.status <> 'closed'
     OR entry_row.clock_in_at IS NULL
     OR entry_row.clock_out_at IS NULL THEN
    DELETE FROM public.employee_overtime_candidates
     WHERE attendance_entry_id = p_attendance_entry_id
       AND status = 'pending';
    RETURN;
  END IF;

  worked_hours := EXTRACT(
    EPOCH FROM entry_row.clock_out_at - entry_row.clock_in_at
  ) / 3600;
  overtime_hours := ROUND(GREATEST(worked_hours - 8, 0), 2);

  IF overtime_hours <= 0 THEN
    DELETE FROM public.employee_overtime_candidates
     WHERE attendance_entry_id = p_attendance_entry_id
       AND status = 'pending';
    RETURN;
  END IF;

  SELECT COALESCE(NULLIF(text_value, '')::numeric, 0)
    INTO rate_value
    FROM public.business_rules
   WHERE restaurant_id = entry_row.restaurant_id
     AND key = 'overtime_hour_rate';

  IF COALESCE(rate_value, 0) <= 0 THEN
    rate_value := 0;
  END IF;

  INSERT INTO public.employee_overtime_candidates (
    restaurant_id, attendance_entry_id, employee_id, worked_date,
    hours, hour_rate, total_amount, status, note
  )
  VALUES (
    entry_row.restaurant_id, entry_row.id, entry_row.employee_id,
    entry_row.work_date, overtime_hours, rate_value,
    ROUND(overtime_hours * rate_value, 2), 'pending',
    'Generado por marcada'
  )
  ON CONFLICT (attendance_entry_id) DO UPDATE
     SET worked_date = EXCLUDED.worked_date,
         hours = EXCLUDED.hours,
         hour_rate = EXCLUDED.hour_rate,
         total_amount = EXCLUDED.total_amount,
         note = EXCLUDED.note,
         updated_at = now()
   WHERE employee_overtime_candidates.status = 'pending';
END;
$$;

CREATE OR REPLACE FUNCTION public.pos_sync_employee_attendance_entry(
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
  entry_id uuid;
  employee_id_value uuid;
BEGIN
  PERFORM public.assert_pos_device(
    p_restaurant_id,
    p_device_id,
    p_device_secret
  );

  entry_id := (p_payload ->> 'id')::uuid;
  employee_id_value := (p_payload ->> 'employee_id')::uuid;

  IF NOT EXISTS (
    SELECT 1 FROM public.employees
     WHERE id = employee_id_value
       AND restaurant_id = p_restaurant_id
       AND is_active = true
       AND show_in_time_clock = true
  ) THEN
    RAISE EXCEPTION 'Empleado no habilitado para marcadas';
  END IF;

  INSERT INTO public.employee_attendance_entries (
    id, local_id, restaurant_id, employee_id, pos_device_id, work_date,
    clock_in_at, clock_out_at, status, source, verification_method,
    note, created_at, updated_at
  )
  VALUES (
    entry_id,
    p_payload ->> 'local_id',
    p_restaurant_id,
    employee_id_value,
    p_device_id,
    (p_payload ->> 'work_date')::date,
    NULLIF(p_payload ->> 'clock_in_at', '')::timestamptz,
    NULLIF(p_payload ->> 'clock_out_at', '')::timestamptz,
    COALESCE(NULLIF(p_payload ->> 'status', ''), 'open'),
    COALESCE(NULLIF(p_payload ->> 'source', ''), 'time_clock'),
    COALESCE(NULLIF(p_payload ->> 'verification_method', ''), 'photo_tap'),
    NULLIF(p_payload ->> 'note', ''),
    COALESCE(NULLIF(p_payload ->> 'created_at', '')::timestamptz, now()),
    now()
  )
  ON CONFLICT (restaurant_id, local_id) DO UPDATE
     SET clock_out_at = COALESCE(
           EXCLUDED.clock_out_at,
           employee_attendance_entries.clock_out_at
         ),
         status = CASE
           WHEN employee_attendance_entries.status = 'voided'
           THEN 'voided'
           ELSE EXCLUDED.status
         END,
         note = COALESCE(EXCLUDED.note, employee_attendance_entries.note),
         updated_at = now()
   WHERE employee_attendance_entries.status <> 'voided'
  RETURNING id INTO entry_id;

  PERFORM public.app_rebuild_overtime_candidate(entry_id);

  RETURN jsonb_build_object('id', entry_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_get_employee_attendance_entries(
  p_restaurant_id uuid,
  p_from date,
  p_to date,
  p_employee_id uuid DEFAULT NULL,
  p_status text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.app_assert_admin_permission(p_restaurant_id, 'marcadas.ver');

  RETURN COALESCE((
    SELECT jsonb_agg(
      jsonb_build_object(
        'id', entry.id,
        'employee_id', entry.employee_id,
        'employee_name', employee.full_name,
        'work_date', entry.work_date,
        'clock_in_at', entry.clock_in_at,
        'clock_out_at', entry.clock_out_at,
        'status', entry.status,
        'source', entry.source,
        'verification_method', entry.verification_method,
        'note', entry.note,
        'device_name', device.name,
        'created_at', entry.created_at
      )
      ORDER BY entry.work_date DESC, entry.created_at DESC
    )
      FROM public.employee_attendance_entries entry
      JOIN public.employees employee ON employee.id = entry.employee_id
      LEFT JOIN public.pos_devices device ON device.id = entry.pos_device_id
     WHERE entry.restaurant_id = p_restaurant_id
       AND entry.work_date BETWEEN p_from AND p_to
       AND (p_employee_id IS NULL OR entry.employee_id = p_employee_id)
       AND (p_status IS NULL OR entry.status = p_status)
  ), '[]'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_save_employee_attendance_entry(
  p_restaurant_id uuid,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  entry_id uuid;
  employee_id_value uuid;
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'marcadas.gestionar'
  );

  entry_id := COALESCE(
    NULLIF(p_payload ->> 'id', '')::uuid,
    gen_random_uuid()
  );
  employee_id_value := (p_payload ->> 'employee_id')::uuid;

  IF NOT EXISTS (
    SELECT 1 FROM public.employees
     WHERE id = employee_id_value
       AND restaurant_id = p_restaurant_id
  ) THEN
    RAISE EXCEPTION 'Empleado no pertenece al restaurante';
  END IF;

  IF EXISTS (
    SELECT 1
      FROM public.employee_overtime_candidates candidate
      JOIN public.employee_overtime_entries overtime
        ON overtime.id = candidate.overtime_entry_id
     WHERE candidate.attendance_entry_id = entry_id
       AND overtime.status = 'paid'
  ) THEN
    RAISE EXCEPTION 'No se puede editar una marcada ya pagada';
  END IF;

  INSERT INTO public.employee_attendance_entries (
    id, restaurant_id, employee_id, work_date, clock_in_at, clock_out_at,
    status, source, verification_method, note, created_by_user_id, updated_at
  )
  VALUES (
    entry_id,
    p_restaurant_id,
    employee_id_value,
    (p_payload ->> 'work_date')::date,
    NULLIF(p_payload ->> 'clock_in_at', '')::timestamptz,
    NULLIF(p_payload ->> 'clock_out_at', '')::timestamptz,
    COALESCE(NULLIF(p_payload ->> 'status', ''), 'closed'),
    'admin',
    COALESCE(NULLIF(p_payload ->> 'verification_method', ''), 'admin'),
    NULLIF(p_payload ->> 'note', ''),
    auth.uid(),
    now()
  )
  ON CONFLICT (id) DO UPDATE
     SET employee_id = EXCLUDED.employee_id,
         work_date = EXCLUDED.work_date,
         clock_in_at = EXCLUDED.clock_in_at,
         clock_out_at = EXCLUDED.clock_out_at,
         status = EXCLUDED.status,
         source = 'admin',
         verification_method = EXCLUDED.verification_method,
         note = EXCLUDED.note,
         updated_at = now()
   WHERE employee_attendance_entries.status <> 'voided';

  PERFORM public.app_rebuild_overtime_candidate(entry_id);

  RETURN jsonb_build_object('id', entry_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_void_employee_attendance_entry(
  p_restaurant_id uuid,
  p_entry_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  linked_overtime_id uuid;
  linked_overtime_status text;
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'marcadas.gestionar'
  );

  SELECT overtime.id, overtime.status
    INTO linked_overtime_id, linked_overtime_status
    FROM public.employee_overtime_candidates candidate
    JOIN public.employee_overtime_entries overtime
      ON overtime.id = candidate.overtime_entry_id
   WHERE candidate.attendance_entry_id = p_entry_id
   LIMIT 1;

  IF linked_overtime_status = 'paid' THEN
    RAISE EXCEPTION 'No se puede anular una marcada ya pagada';
  END IF;

  IF linked_overtime_id IS NOT NULL THEN
    DELETE FROM public.employee_overtime_entries
     WHERE id = linked_overtime_id
       AND status = 'pending';
  END IF;

  UPDATE public.employee_attendance_entries
     SET status = 'voided',
         updated_at = now()
   WHERE id = p_entry_id
     AND restaurant_id = p_restaurant_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Marcada no pertenece al restaurante';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.app_get_employee_overtime_candidates(
  p_restaurant_id uuid,
  p_from date,
  p_to date,
  p_status text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'horas_extra.autorizar'
  );

  RETURN COALESCE((
    SELECT jsonb_agg(
      jsonb_build_object(
        'id', candidate.id,
        'attendance_entry_id', candidate.attendance_entry_id,
        'employee_id', candidate.employee_id,
        'employee_name', employee.full_name,
        'worked_date', candidate.worked_date,
        'hours', candidate.hours,
        'hour_rate', candidate.hour_rate,
        'total_amount', candidate.total_amount,
        'status', candidate.status,
        'note', candidate.note
      )
      ORDER BY candidate.worked_date DESC, employee.full_name
    )
      FROM public.employee_overtime_candidates candidate
      JOIN public.employees employee ON employee.id = candidate.employee_id
     WHERE candidate.restaurant_id = p_restaurant_id
       AND candidate.worked_date BETWEEN p_from AND p_to
       AND (p_status IS NULL OR candidate.status = p_status)
  ), '[]'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_approve_employee_overtime_candidate(
  p_restaurant_id uuid,
  p_candidate_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  candidate_row public.employee_overtime_candidates%ROWTYPE;
  overtime_id uuid;
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'horas_extra.autorizar'
  );

  SELECT *
    INTO candidate_row
    FROM public.employee_overtime_candidates
   WHERE id = p_candidate_id
     AND restaurant_id = p_restaurant_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Hora extra no pertenece al restaurante';
  END IF;
  IF candidate_row.status <> 'pending' THEN
    RAISE EXCEPTION 'La hora extra ya fue procesada';
  END IF;

  INSERT INTO public.employee_overtime_entries (
    restaurant_id, employee_id, worked_date, hours, hour_rate,
    total_amount, note, status, created_by_user_id
  )
  VALUES (
    p_restaurant_id, candidate_row.employee_id, candidate_row.worked_date,
    candidate_row.hours, candidate_row.hour_rate, candidate_row.total_amount,
    candidate_row.note, 'pending', auth.uid()
  )
  RETURNING id INTO overtime_id;

  UPDATE public.employee_overtime_candidates
     SET status = 'approved',
         overtime_entry_id = overtime_id,
         approved_by_user_id = auth.uid(),
         approved_at = now(),
         updated_at = now()
   WHERE id = p_candidate_id;

  RETURN jsonb_build_object('overtime_entry_id', overtime_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_reject_employee_overtime_candidate(
  p_restaurant_id uuid,
  p_candidate_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'horas_extra.autorizar'
  );

  UPDATE public.employee_overtime_candidates
     SET status = 'rejected',
         approved_by_user_id = auth.uid(),
         approved_at = now(),
         updated_at = now()
   WHERE id = p_candidate_id
     AND restaurant_id = p_restaurant_id
     AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'La hora extra no esta pendiente';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.app_list_pos_devices_for_cleanup(
  p_restaurant_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'sistema.reiniciar_operacion'
  );

  RETURN COALESCE((
    SELECT jsonb_agg(
      jsonb_build_object(
        'id', device.id,
        'name', COALESCE(device.name, 'POS sin nombre'),
        'is_active', device.is_active,
        'last_seen_at', device.last_seen_at,
        'sales_count', COALESCE(sale_counts.sales_count, 0),
        'staff_consumptions_count',
          COALESCE(sale_counts.staff_consumptions_count, 0),
        'expenses_count', COALESCE(expense_counts.expenses_count, 0),
        'salary_advances_count',
          COALESCE(advance_counts.salary_advances_count, 0),
        'cash_sessions_count', COALESCE(cash_counts.cash_sessions_count, 0),
        'inventory_movements_count',
          COALESCE(inventory_counts.inventory_movements_count, 0),
        'packaging_movements_count',
          COALESCE(packaging_counts.packaging_movements_count, 0),
        'attendance_count', COALESCE(attendance_counts.attendance_count, 0),
        'overtime_candidates_count',
          COALESCE(attendance_counts.overtime_candidates_count, 0),
        'last_activity_at',
          GREATEST(
            COALESCE(sale_counts.last_activity_at, '-infinity'::timestamptz),
            COALESCE(expense_counts.last_activity_at, '-infinity'::timestamptz),
            COALESCE(advance_counts.last_activity_at, '-infinity'::timestamptz),
            COALESCE(cash_counts.last_activity_at, '-infinity'::timestamptz),
            COALESCE(attendance_counts.last_activity_at, '-infinity'::timestamptz)
          )
      )
      ORDER BY
        GREATEST(
          COALESCE(sale_counts.last_activity_at, '-infinity'::timestamptz),
          COALESCE(expense_counts.last_activity_at, '-infinity'::timestamptz),
          COALESCE(advance_counts.last_activity_at, '-infinity'::timestamptz),
          COALESCE(cash_counts.last_activity_at, '-infinity'::timestamptz),
          COALESCE(attendance_counts.last_activity_at, '-infinity'::timestamptz),
          COALESCE(device.last_seen_at, '-infinity'::timestamptz)
        ) DESC,
        device.created_at DESC
    )
    FROM public.pos_devices device
    LEFT JOIN LATERAL (
      SELECT
        COUNT(*) FILTER (WHERE sale.sale_kind = 'sale') AS sales_count,
        COUNT(*) FILTER (
          WHERE sale.sale_kind = 'staff_consumption'
        ) AS staff_consumptions_count,
        MAX(sale.sold_at) AS last_activity_at
      FROM public.sales sale
      WHERE sale.restaurant_id = p_restaurant_id
        AND sale.pos_device_id = device.id
    ) sale_counts ON true
    LEFT JOIN LATERAL (
      SELECT COUNT(*) AS expenses_count, MAX(expense.spent_at) AS last_activity_at
      FROM public.operating_expenses expense
      WHERE expense.restaurant_id = p_restaurant_id
        AND expense.pos_device_id = device.id
    ) expense_counts ON true
    LEFT JOIN LATERAL (
      SELECT COUNT(*) AS salary_advances_count,
             MAX(advance.delivered_at) AS last_activity_at
      FROM public.employee_salary_advances advance
      WHERE advance.restaurant_id = p_restaurant_id
        AND advance.pos_device_id = device.id
    ) advance_counts ON true
    LEFT JOIN LATERAL (
      SELECT COUNT(*) AS cash_sessions_count,
             MAX(COALESCE(cash.closed_at, cash.opened_at)) AS last_activity_at
      FROM public.cash_register_sessions cash
      WHERE cash.restaurant_id = p_restaurant_id
        AND cash.pos_device_id = device.id
    ) cash_counts ON true
    LEFT JOIN LATERAL (
      SELECT COUNT(*) AS inventory_movements_count
      FROM public.inventory_movements movement
      WHERE movement.restaurant_id = p_restaurant_id
        AND movement.pos_device_id = device.id
    ) inventory_counts ON true
    LEFT JOIN LATERAL (
      SELECT COUNT(*) AS packaging_movements_count
      FROM public.packaging_movements movement
      WHERE movement.restaurant_id = p_restaurant_id
        AND movement.pos_device_id = device.id
    ) packaging_counts ON true
    LEFT JOIN LATERAL (
      SELECT
        COUNT(*) AS attendance_count,
        COUNT(candidate.id) AS overtime_candidates_count,
        MAX(entry.updated_at) AS last_activity_at
      FROM public.employee_attendance_entries entry
      LEFT JOIN public.employee_overtime_candidates candidate
        ON candidate.attendance_entry_id = entry.id
      WHERE entry.restaurant_id = p_restaurant_id
        AND entry.pos_device_id = device.id
    ) attendance_counts ON true
    WHERE device.restaurant_id = p_restaurant_id
  ), '[]'::jsonb);
END;
$$;

DO $$
BEGIN
  IF to_regprocedure(
    'public.app_cleanup_pos_device_test_data_legacy(uuid, uuid, text)'
  ) IS NULL THEN
    ALTER FUNCTION public.app_cleanup_pos_device_test_data(uuid, uuid, text)
      RENAME TO app_cleanup_pos_device_test_data_legacy;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.app_cleanup_pos_device_test_data(
  p_restaurant_id uuid,
  p_device_id uuid,
  p_confirmation text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  deleted_attendance_entries integer := 0;
  deleted_overtime_candidates integer := 0;
  deleted_overtime_entries integer := 0;
  base_result jsonb;
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'sistema.reiniciar_operacion'
  );

  IF p_confirmation <> 'BORRAR DISPOSITIVO' THEN
    RAISE EXCEPTION 'Confirmacion invalida para limpieza por dispositivo'
      USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.employee_attendance_entries entry
    JOIN public.employee_overtime_candidates candidate
      ON candidate.attendance_entry_id = entry.id
    JOIN public.employee_overtime_entries overtime
      ON overtime.id = candidate.overtime_entry_id
    WHERE entry.restaurant_id = p_restaurant_id
      AND entry.pos_device_id = p_device_id
      AND overtime.status = 'paid'
  ) THEN
    RAISE EXCEPTION
      'Primero debes revertir la planilla ligada a marcadas de este dispositivo'
      USING ERRCODE = '23503';
  END IF;

  DELETE FROM public.employee_overtime_entries overtime
  USING public.employee_overtime_candidates candidate,
        public.employee_attendance_entries entry
  WHERE overtime.id = candidate.overtime_entry_id
    AND candidate.attendance_entry_id = entry.id
    AND entry.restaurant_id = p_restaurant_id
    AND entry.pos_device_id = p_device_id
    AND overtime.status <> 'paid';
  GET DIAGNOSTICS deleted_overtime_entries = ROW_COUNT;

  DELETE FROM public.employee_overtime_candidates candidate
  USING public.employee_attendance_entries entry
  WHERE candidate.attendance_entry_id = entry.id
    AND entry.restaurant_id = p_restaurant_id
    AND entry.pos_device_id = p_device_id;
  GET DIAGNOSTICS deleted_overtime_candidates = ROW_COUNT;

  DELETE FROM public.employee_attendance_entries
  WHERE restaurant_id = p_restaurant_id
    AND pos_device_id = p_device_id;
  GET DIAGNOSTICS deleted_attendance_entries = ROW_COUNT;

  base_result := public.app_cleanup_pos_device_test_data_legacy(
    p_restaurant_id,
    p_device_id,
    p_confirmation
  );

  RETURN base_result || jsonb_build_object(
    'deleted_attendance_entries', deleted_attendance_entries,
    'deleted_overtime_candidates', deleted_overtime_candidates,
    'deleted_overtime_entries', deleted_overtime_entries,
    'total_rows',
      COALESCE((base_result ->> 'total_rows')::integer, 0) +
      deleted_attendance_entries +
      deleted_overtime_candidates +
      deleted_overtime_entries
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.pos_sync_employee_attendance_entry(
  uuid, uuid, text, jsonb
) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_get_employee_attendance_entries(
  uuid, date, date, uuid, text
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_save_employee_attendance_entry(
  uuid, jsonb
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_void_employee_attendance_entry(
  uuid, uuid
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_get_employee_overtime_candidates(
  uuid, date, date, text
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_approve_employee_overtime_candidate(
  uuid, uuid
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_reject_employee_overtime_candidate(
  uuid, uuid
) TO authenticated;
REVOKE ALL ON FUNCTION public.app_list_pos_devices_for_cleanup(uuid)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.app_cleanup_pos_device_test_data(
  uuid, uuid, text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.app_list_pos_devices_for_cleanup(uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_cleanup_pos_device_test_data(
  uuid, uuid, text
) TO authenticated;
