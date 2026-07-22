-- Hardens attendance marks for V1:
-- - one non-voided attendance entry per employee/work date;
-- - admin deletion is permanent when the entry is not linked to paid payroll.

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
  local_id_value text;
  status_value text;
  work_date_value date;
BEGIN
  PERFORM public.assert_pos_device(
    p_restaurant_id,
    p_device_id,
    p_device_secret
  );

  entry_id := (p_payload ->> 'id')::uuid;
  local_id_value := p_payload ->> 'local_id';
  employee_id_value := (p_payload ->> 'employee_id')::uuid;
  status_value := COALESCE(NULLIF(p_payload ->> 'status', ''), 'open');
  work_date_value := (p_payload ->> 'work_date')::date;

  IF NOT EXISTS (
    SELECT 1 FROM public.employees
     WHERE id = employee_id_value
       AND restaurant_id = p_restaurant_id
       AND is_active = true
       AND show_in_time_clock = true
  ) THEN
    RAISE EXCEPTION 'Empleado no habilitado para marcadas';
  END IF;

  IF status_value <> 'voided' AND EXISTS (
    SELECT 1
      FROM public.employee_attendance_entries entry
     WHERE entry.restaurant_id = p_restaurant_id
       AND entry.employee_id = employee_id_value
       AND entry.work_date = work_date_value
       AND entry.status <> 'voided'
       AND entry.local_id IS DISTINCT FROM local_id_value
  ) THEN
    RAISE EXCEPTION 'Empleado ya tiene marcada registrada para esta fecha';
  END IF;

  INSERT INTO public.employee_attendance_entries (
    id, local_id, restaurant_id, employee_id, pos_device_id, work_date,
    clock_in_at, clock_out_at, status, source, verification_method,
    note, created_at, updated_at
  )
  VALUES (
    entry_id,
    local_id_value,
    p_restaurant_id,
    employee_id_value,
    p_device_id,
    work_date_value,
    NULLIF(p_payload ->> 'clock_in_at', '')::timestamptz,
    NULLIF(p_payload ->> 'clock_out_at', '')::timestamptz,
    status_value,
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

  IF entry_id IS NOT NULL THEN
    PERFORM public.app_rebuild_overtime_candidate(entry_id);
  END IF;

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
       AND entry.status <> 'voided'
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
  status_value text;
  work_date_value date;
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'marcadas.gestionar'
  );

  entry_id := COALESCE(NULLIF(p_payload ->> 'id', '')::uuid, gen_random_uuid());
  employee_id_value := (p_payload ->> 'employee_id')::uuid;
  status_value := COALESCE(NULLIF(p_payload ->> 'status', ''), 'closed');
  work_date_value := (p_payload ->> 'work_date')::date;

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

  IF status_value <> 'voided' AND EXISTS (
    SELECT 1
      FROM public.employee_attendance_entries entry
     WHERE entry.restaurant_id = p_restaurant_id
       AND entry.employee_id = employee_id_value
       AND entry.work_date = work_date_value
       AND entry.status <> 'voided'
       AND entry.id <> entry_id
  ) THEN
    RAISE EXCEPTION 'Empleado ya tiene marcada registrada para esta fecha';
  END IF;

  INSERT INTO public.employee_attendance_entries (
    id, restaurant_id, employee_id, work_date, clock_in_at, clock_out_at,
    status, source, verification_method, note, created_by_user_id, updated_at
  )
  VALUES (
    entry_id,
    p_restaurant_id,
    employee_id_value,
    work_date_value,
    NULLIF(p_payload ->> 'clock_in_at', '')::timestamptz,
    NULLIF(p_payload ->> 'clock_out_at', '')::timestamptz,
    status_value,
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
    RAISE EXCEPTION 'No se puede eliminar una marcada ya pagada';
  END IF;

  DELETE FROM public.employee_overtime_candidates
   WHERE attendance_entry_id = p_entry_id;

  IF linked_overtime_id IS NOT NULL THEN
    DELETE FROM public.employee_overtime_entries
     WHERE id = linked_overtime_id
       AND status = 'pending';
  END IF;

  DELETE FROM public.employee_attendance_entries
   WHERE id = p_entry_id
     AND restaurant_id = p_restaurant_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Marcada no pertenece al restaurante';
  END IF;
END;
$$;
