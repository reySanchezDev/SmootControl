-- Read RPCs for vacation inbox and consolidated balance report.

CREATE OR REPLACE FUNCTION public.app_get_employee_vacation_requests(
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
  PERFORM public.app_assert_admin_permission(p_restaurant_id, 'vacaciones.ver');

  RETURN COALESCE((
    SELECT jsonb_agg(
      jsonb_build_object(
        'id', request.id,
        'employee_id', request.employee_id,
        'employee_name', employee.full_name,
        'start_date', request.start_date,
        'end_date', request.end_date,
        'requested_days', request.requested_days,
        'request_type', request.request_type,
        'status', request.status,
        'source', request.source,
        'note', request.note,
        'device_name', device.name,
        'approved_at', request.approved_at,
        'created_at', request.created_at
      )
      ORDER BY request.start_date DESC, request.created_at DESC
    )
      FROM public.employee_vacation_requests request
      JOIN public.employees employee ON employee.id = request.employee_id
      LEFT JOIN public.pos_devices device ON device.id = request.pos_device_id
     WHERE request.restaurant_id = p_restaurant_id
       AND request.start_date <= p_to
       AND request.end_date >= p_from
       AND (p_employee_id IS NULL OR request.employee_id = p_employee_id)
       AND (p_status IS NULL OR request.status = p_status)
  ), '[]'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_get_employee_vacation_summary(
  p_restaurant_id uuid,
  p_as_of date,
  p_employee_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  monthly_rate numeric(8, 4);
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'reportes.vacaciones.ver'
  );

  SELECT COALESCE(NULLIF(rule.text_value, '')::numeric, 2.5)
    INTO monthly_rate
    FROM public.business_rules rule
   WHERE rule.restaurant_id = p_restaurant_id
     AND rule.key = 'vacation_days_per_month';

  monthly_rate := COALESCE(monthly_rate, 2.5);

  RETURN COALESCE((
    WITH employee_base AS (
      SELECT
        employee.id,
        employee.full_name,
        COALESCE(
          employee.vacation_accrual_start_date,
          employee.created_at::date
        ) AS start_date
      FROM public.employees employee
      WHERE employee.restaurant_id = p_restaurant_id
        AND employee.is_active = true
        AND (p_employee_id IS NULL OR employee.id = p_employee_id)
    ),
    request_totals AS (
      SELECT
        request.employee_id,
        SUM(request.requested_days) FILTER (
          WHERE request.status = 'approved'
            AND request.end_date <= p_as_of
        ) AS taken_days,
        SUM(request.requested_days) FILTER (
          WHERE request.status = 'approved'
            AND request.start_date > p_as_of
        ) AS scheduled_days,
        MIN(request.start_date) FILTER (
          WHERE request.status = 'approved'
            AND request.start_date > p_as_of
        ) AS scheduled_from,
        MAX(request.end_date) FILTER (
          WHERE request.status = 'approved'
            AND request.start_date > p_as_of
        ) AS scheduled_to
      FROM public.employee_vacation_requests request
      WHERE request.restaurant_id = p_restaurant_id
      GROUP BY request.employee_id
    )
    SELECT jsonb_agg(
      jsonb_build_object(
        'employee_id', employee_base.id,
        'employee_name', employee_base.full_name,
        'start_date', employee_base.start_date,
        'accumulated_days', ROUND(
          GREATEST(0, (p_as_of - employee_base.start_date + 1))
          * monthly_rate / 30.0,
          2
        ),
        'taken_days', COALESCE(request_totals.taken_days, 0),
        'scheduled_days', COALESCE(request_totals.scheduled_days, 0),
        'scheduled_from', request_totals.scheduled_from,
        'scheduled_to', request_totals.scheduled_to,
        'current_balance', ROUND(
          GREATEST(0, (p_as_of - employee_base.start_date + 1))
          * monthly_rate / 30.0,
          2
        ) - COALESCE(request_totals.taken_days, 0),
        'projected_balance', ROUND(
          GREATEST(0, (p_as_of - employee_base.start_date + 1))
          * monthly_rate / 30.0,
          2
        ) - COALESCE(request_totals.taken_days, 0)
          - COALESCE(request_totals.scheduled_days, 0)
      )
      ORDER BY employee_base.full_name
    )
    FROM employee_base
    LEFT JOIN request_totals ON request_totals.employee_id = employee_base.id
  ), '[]'::jsonb);
END;
$$;

REVOKE ALL ON FUNCTION public.app_get_employee_vacation_requests(
  uuid, date, date, uuid, text
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.app_get_employee_vacation_summary(
  uuid, date, uuid
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.app_get_employee_vacation_requests(
  uuid, date, date, uuid, text
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_get_employee_vacation_summary(
  uuid, date, uuid
) TO authenticated;
