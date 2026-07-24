-- Adds employee work shifts for attendance reporting and payroll control.

CREATE TABLE IF NOT EXISTS public.employee_work_shifts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  name text NOT NULL,
  start_time time NOT NULL,
  end_time time NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (restaurant_id, name)
);

ALTER TABLE public.employee_work_shifts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS employee_work_shifts_same_restaurant
  ON public.employee_work_shifts;
CREATE POLICY employee_work_shifts_same_restaurant
  ON public.employee_work_shifts
  FOR ALL TO authenticated
  USING (public.is_same_restaurant(restaurant_id))
  WITH CHECK (public.is_same_restaurant(restaurant_id));

ALTER TABLE public.employees
  ADD COLUMN IF NOT EXISTS work_shift_id uuid
  REFERENCES public.employee_work_shifts(id);

INSERT INTO public.permissions (code, name)
VALUES ('turnos.gestionar', 'Gestionar turnos')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT role.id, permission.id
  FROM public.roles role
  JOIN public.permissions permission ON permission.code = 'turnos.gestionar'
 WHERE role.code = 'admin'
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION public.app_save_employee_work_shift(
  p_restaurant_id uuid,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  shift_id uuid;
  result_row jsonb;
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'turnos.gestionar'
  );

  shift_id := NULLIF(btrim(COALESCE(p_payload ->> 'id', '')), '')::uuid;
  shift_id := COALESCE(shift_id, gen_random_uuid());

  INSERT INTO public.employee_work_shifts (
    id, restaurant_id, name, start_time, end_time, is_active, updated_at
  )
  VALUES (
    shift_id,
    p_restaurant_id,
    upper(NULLIF(btrim(p_payload ->> 'name'), '')),
    (p_payload ->> 'start_time')::time,
    (p_payload ->> 'end_time')::time,
    COALESCE((p_payload ->> 'is_active')::boolean, true),
    now()
  )
  ON CONFLICT (restaurant_id, name) DO UPDATE
     SET start_time = EXCLUDED.start_time,
         end_time = EXCLUDED.end_time,
         is_active = EXCLUDED.is_active,
         updated_at = now()
  RETURNING jsonb_build_object(
    'id', employee_work_shifts.id,
    'name', employee_work_shifts.name,
    'start_time', to_char(employee_work_shifts.start_time, 'HH24:MI'),
    'end_time', to_char(employee_work_shifts.end_time, 'HH24:MI'),
    'is_active', employee_work_shifts.is_active
  )
  INTO result_row;

  RETURN result_row;
END;
$$;

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
  work_shift_id_value uuid;
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
  work_shift_id_value := NULLIF(
    btrim(COALESCE(p_payload ->> 'work_shift_id', '')),
    ''
  )::uuid;

  IF position_id_value IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.employee_positions
     WHERE id = position_id_value AND restaurant_id = p_restaurant_id
  ) THEN
    RAISE EXCEPTION 'Puesto no pertenece al restaurante';
  END IF;

  IF work_shift_id_value IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.employee_work_shifts
     WHERE id = work_shift_id_value AND restaurant_id = p_restaurant_id
  ) THEN
    RAISE EXCEPTION 'Turno no pertenece al restaurante';
  END IF;

  IF employee_id IS NULL THEN
    INSERT INTO public.employee_number_settings (restaurant_id, next_number)
    VALUES (p_restaurant_id, 1)
    ON CONFLICT (restaurant_id) DO NOTHING;

    SELECT next_number INTO employee_number_value
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
      position_name, work_shift_id, base_salary, is_active, photo_url,
      show_in_time_clock, updated_at
    )
    VALUES (
      employee_id, p_restaurant_id, employee_number_value,
      employee_number_value::text, NULLIF(btrim(p_payload ->> 'full_name'), ''),
      position_id_value,
      (SELECT name FROM public.employee_positions WHERE id = position_id_value),
      work_shift_id_value,
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
             SELECT name FROM public.employee_positions
              WHERE id = position_id_value
           ),
           work_shift_id = work_shift_id_value,
           base_salary = COALESCE((p_payload ->> 'base_salary')::numeric, 0),
           is_active = COALESCE((p_payload ->> 'is_active')::boolean, true),
           photo_url = NULLIF(btrim(COALESCE(p_payload ->> 'photo_url', '')), ''),
           show_in_time_clock =
             COALESCE((p_payload ->> 'show_in_time_clock')::boolean, true),
           updated_at = now()
     WHERE id = employee_id AND restaurant_id = p_restaurant_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Empleado no pertenece al restaurante';
    END IF;
  END IF;

  SELECT jsonb_build_object(
    'id', employee.id,
    'code', employee.code,
    'employee_number', employee.employee_number,
    'full_name', employee.full_name,
    'position_id', employee.position_id,
    'position_name', employee.position_name,
    'work_shift_id', employee.work_shift_id,
    'work_shift_name', shift.name,
    'work_shift_start_time', to_char(shift.start_time, 'HH24:MI'),
    'work_shift_end_time', to_char(shift.end_time, 'HH24:MI'),
    'base_salary', employee.base_salary,
    'is_active', employee.is_active,
    'photo_url', employee.photo_url,
    'show_in_time_clock', employee.show_in_time_clock
  )
  INTO result_row
  FROM public.employees employee
  LEFT JOIN public.employee_work_shifts shift ON shift.id = employee.work_shift_id
  WHERE employee.id = employee_id;

  RETURN result_row;
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
        'work_shift_name', shift.name,
        'work_shift_start_time', to_char(shift.start_time, 'HH24:MI'),
        'work_shift_end_time', to_char(shift.end_time, 'HH24:MI'),
        'created_at', entry.created_at
      )
      ORDER BY entry.work_date DESC, entry.created_at DESC
    )
      FROM public.employee_attendance_entries entry
      JOIN public.employees employee ON employee.id = entry.employee_id
      LEFT JOIN public.employee_work_shifts shift ON shift.id = employee.work_shift_id
      LEFT JOIN public.pos_devices device ON device.id = entry.pos_device_id
     WHERE entry.restaurant_id = p_restaurant_id
       AND entry.work_date BETWEEN p_from AND p_to
       AND entry.status <> 'voided'
       AND (p_employee_id IS NULL OR entry.employee_id = p_employee_id)
       AND (p_status IS NULL OR entry.status = p_status)
  ), '[]'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_save_employee_work_shift(uuid, jsonb)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_save_employee(uuid, jsonb)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_get_employee_attendance_entries(
  uuid, date, date, uuid, text
) TO authenticated;
