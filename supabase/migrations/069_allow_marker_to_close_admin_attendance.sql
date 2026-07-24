-- Allows the time-clock device to close an attendance entry created from admin.
-- Admin-created entries can have NULL local_id, so POS sync must match by id.

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
  existing_id uuid;
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

  SELECT entry.id
    INTO existing_id
    FROM public.employee_attendance_entries entry
   WHERE entry.id = entry_id
     AND entry.restaurant_id = p_restaurant_id
     AND entry.employee_id = employee_id_value
     AND entry.work_date = work_date_value
     AND entry.status <> 'voided'
   LIMIT 1;

  IF existing_id IS NOT NULL THEN
    UPDATE public.employee_attendance_entries
       SET local_id = COALESCE(employee_attendance_entries.local_id, local_id_value),
           pos_device_id = COALESCE(employee_attendance_entries.pos_device_id, p_device_id),
           clock_out_at = COALESCE(
             NULLIF(p_payload ->> 'clock_out_at', '')::timestamptz,
             employee_attendance_entries.clock_out_at
           ),
           status = status_value,
           verification_method = COALESCE(
             NULLIF(p_payload ->> 'verification_method', ''),
             employee_attendance_entries.verification_method
           ),
           note = COALESCE(NULLIF(p_payload ->> 'note', ''), employee_attendance_entries.note),
           updated_at = now()
     WHERE id = existing_id;

    PERFORM public.app_rebuild_overtime_candidate(existing_id);
    RETURN jsonb_build_object('id', existing_id);
  END IF;

  IF status_value <> 'voided' AND EXISTS (
    SELECT 1
      FROM public.employee_attendance_entries entry
     WHERE entry.restaurant_id = p_restaurant_id
       AND entry.employee_id = employee_id_value
       AND entry.work_date = work_date_value
       AND entry.status <> 'voided'
       AND entry.id <> entry_id
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

GRANT EXECUTE ON FUNCTION public.pos_sync_employee_attendance_entry(
  uuid,
  uuid,
  text,
  jsonb
) TO anon, authenticated;
