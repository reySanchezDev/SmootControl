-- Extends attendance report rows with overtime candidate status.

INSERT INTO public.employee_work_shifts (
  restaurant_id,
  name,
  start_time,
  end_time,
  is_active
)
SELECT restaurant.id, 'TURNO A', '08:00'::time, '17:00'::time, true
  FROM public.restaurants restaurant
ON CONFLICT (restaurant_id, name) DO NOTHING;

INSERT INTO public.employee_work_shifts (
  restaurant_id,
  name,
  start_time,
  end_time,
  is_active
)
SELECT restaurant.id, 'TURNO B', '15:00'::time, '22:00'::time, true
  FROM public.restaurants restaurant
ON CONFLICT (restaurant_id, name) DO NOTHING;

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
        'work_shift_name', shift.name,
        'work_shift_start_time', to_char(shift.start_time, 'HH24:MI'),
        'work_shift_end_time', to_char(shift.end_time, 'HH24:MI'),
        'overtime_hours', candidate.hours,
        'overtime_status', candidate.status,
        'created_at', entry.created_at
      )
      ORDER BY entry.work_date DESC, entry.created_at DESC
    )
      FROM public.employee_attendance_entries entry
      JOIN public.employees employee ON employee.id = entry.employee_id
      LEFT JOIN public.employee_work_shifts shift
        ON shift.id = employee.work_shift_id
      LEFT JOIN public.pos_devices device ON device.id = entry.pos_device_id
      LEFT JOIN public.employee_overtime_candidates candidate
        ON candidate.attendance_entry_id = entry.id
     WHERE entry.restaurant_id = p_restaurant_id
       AND entry.work_date BETWEEN p_from AND p_to
       AND entry.status <> 'voided'
       AND (p_employee_id IS NULL OR entry.employee_id = p_employee_id)
       AND (p_status IS NULL OR entry.status = p_status)
  ), '[]'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_get_employee_attendance_entries(
  uuid,
  date,
  date,
  uuid,
  text
) TO authenticated;
