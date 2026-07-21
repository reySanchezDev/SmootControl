DROP INDEX IF EXISTS public.cash_register_one_open_per_user_day_idx;

CREATE UNIQUE INDEX IF NOT EXISTS cash_register_one_open_per_user_day_device_idx
  ON public.cash_register_sessions (
    restaurant_id,
    cashier_user_id,
    business_date,
    pos_device_id
  )
  WHERE status = 'open'
    AND pos_device_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS cash_register_one_open_per_user_day_legacy_idx
  ON public.cash_register_sessions (
    restaurant_id,
    cashier_user_id,
    business_date
  )
  WHERE status = 'open'
    AND pos_device_id IS NULL;

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
  session_id uuid;
  original_session_id uuid;
  remote_session_id uuid;
  cashier_id uuid;
  business_day date;
  session_status text;
BEGIN
  PERFORM public.assert_pos_device(
    p_restaurant_id,
    p_device_id,
    p_device_secret
  );

  session_id := (p_payload ->> 'id')::uuid;
  original_session_id := session_id;
  cashier_id := (p_payload ->> 'cashier_user_id')::uuid;
  business_day := COALESCE(
    NULLIF(p_payload ->> 'business_date', '')::date,
    CURRENT_DATE
  );
  session_status := COALESCE(NULLIF(p_payload ->> 'status', ''), 'open');

  SELECT id
    INTO remote_session_id
    FROM public.cash_register_sessions
   WHERE id = session_id
     AND restaurant_id = p_restaurant_id
   LIMIT 1;

  IF remote_session_id IS NULL THEN
    SELECT id
      INTO remote_session_id
      FROM public.cash_register_sessions
     WHERE restaurant_id = p_restaurant_id
       AND cashier_user_id = cashier_id
       AND business_date = business_day
       AND pos_device_id = p_device_id
     ORDER BY
       CASE WHEN status = 'open' THEN 0 ELSE 1 END,
       opened_at ASC,
       updated_at ASC
     LIMIT 1;
  END IF;

  IF remote_session_id IS NOT NULL AND remote_session_id <> session_id THEN
    session_id := remote_session_id;
  END IF;

  INSERT INTO public.cash_register_sessions (
    id,
    restaurant_id,
    cashier_user_id,
    pos_device_id,
    business_date,
    opening_cash_amount,
    counted_cash_amount,
    status,
    closed_at,
    updated_at
  )
  VALUES (
    session_id,
    p_restaurant_id,
    cashier_id,
    p_device_id,
    business_day,
    COALESCE((p_payload ->> 'opening_cash_amount')::numeric, 0),
    NULLIF(p_payload ->> 'counted_cash_amount', '')::numeric,
    session_status,
    CASE
      WHEN session_status = 'closed' THEN COALESCE(
        NULLIF(p_payload ->> 'closed_at', '')::timestamptz,
        now()
      )
      ELSE NULL
    END,
    now()
  )
  ON CONFLICT (id) DO UPDATE
     SET pos_device_id = COALESCE(
           cash_register_sessions.pos_device_id,
           excluded.pos_device_id
         ),
         opening_cash_amount = CASE
           WHEN cash_register_sessions.status = 'closed'
           THEN cash_register_sessions.opening_cash_amount
           ELSE excluded.opening_cash_amount
         END,
         counted_cash_amount = COALESCE(
           excluded.counted_cash_amount,
           cash_register_sessions.counted_cash_amount
         ),
         status = CASE
           WHEN cash_register_sessions.status = 'closed'
           THEN 'closed'
           ELSE excluded.status
         END,
         closed_at = COALESCE(
           cash_register_sessions.closed_at,
           excluded.closed_at
         ),
         updated_at = now();

  RETURN jsonb_build_object(
    'remote_id',
    session_id,
    'aliased',
    remote_session_id IS NOT NULL AND remote_session_id <> original_session_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.pos_sync_cash_register_session(
  uuid,
  uuid,
  text,
  jsonb
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.pos_sync_cash_register_session(
  uuid,
  uuid,
  text,
  jsonb
) TO anon, authenticated, service_role;
