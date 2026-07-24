-- Allows the standalone time-clock APK to refresh today's attendance state
-- with device credentials, without requiring an admin session.

CREATE OR REPLACE FUNCTION public.pos_get_employee_attendance_entries(
  p_restaurant_id uuid,
  p_device_id uuid,
  p_device_secret text,
  p_from date,
  p_to date,
  p_employee_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.assert_pos_device(
    p_restaurant_id,
    p_device_id,
    p_device_secret
  );

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
  ), '[]'::jsonb);
END;
$$;

REVOKE ALL ON FUNCTION public.pos_get_employee_attendance_entries(
  uuid, uuid, text, date, date, uuid
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.pos_get_employee_attendance_entries(
  uuid, uuid, text, date, date, uuid
) TO anon, authenticated;
