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
  expense_id uuid;
  cash_session_id uuid;
  actor_id uuid;
BEGIN
  PERFORM public.assert_pos_device(
    p_restaurant_id,
    p_device_id,
    p_device_secret
  );

  expense_id := (p_payload ->> 'id')::uuid;
  actor_id := (p_payload ->> 'created_by_user_id')::uuid;
  cash_session_id := NULLIF(
    p_payload ->> 'cash_register_session_id',
    ''
  )::uuid;

  IF cash_session_id IS NOT NULL AND NOT EXISTS (
    SELECT 1
      FROM public.cash_register_sessions
     WHERE id = cash_session_id
       AND restaurant_id = p_restaurant_id
  ) THEN
    SELECT id
      INTO cash_session_id
      FROM public.cash_register_sessions
     WHERE restaurant_id = p_restaurant_id
       AND cashier_user_id = actor_id
       AND status = 'open'
     ORDER BY opened_at DESC
     LIMIT 1;
  END IF;

  INSERT INTO public.operating_expenses (
    id,
    local_id,
    restaurant_id,
    expense_category_id,
    cash_register_session_id,
    created_by_user_id,
    description,
    amount,
    sync_status,
    spent_at,
    updated_at
  )
  VALUES (
    expense_id,
    p_payload ->> 'local_id',
    p_restaurant_id,
    (p_payload ->> 'expense_category_id')::uuid,
    cash_session_id,
    actor_id,
    p_payload ->> 'description',
    (p_payload ->> 'amount')::numeric,
    'synced',
    COALESCE(NULLIF(p_payload ->> 'spent_at', '')::timestamptz, now()),
    now()
  )
  ON CONFLICT (id) DO UPDATE
     SET cash_register_session_id = excluded.cash_register_session_id,
         description = excluded.description,
         amount = excluded.amount,
         sync_status = 'synced',
         updated_at = now();

  RETURN jsonb_build_object('remote_id', expense_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.pos_sync_table_account(
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
  account_id uuid;
BEGIN
  PERFORM public.assert_pos_device(
    p_restaurant_id,
    p_device_id,
    p_device_secret
  );

  account_id := (p_payload ->> 'id')::uuid;

  INSERT INTO public.table_accounts (
    id,
    restaurant_id,
    table_id,
    name,
    status,
    created_by_user_id,
    updated_at
  )
  VALUES (
    account_id,
    p_restaurant_id,
    (p_payload ->> 'table_id')::uuid,
    p_payload ->> 'name',
    COALESCE(p_payload ->> 'status', 'open'),
    (p_payload ->> 'created_by_user_id')::uuid,
    now()
  )
  ON CONFLICT (id) DO UPDATE
     SET name = excluded.name,
         status = excluded.status,
         updated_at = now();

  RETURN jsonb_build_object('remote_id', account_id);
END;
$$;

REVOKE ALL ON FUNCTION public.pos_sync_operating_expense(
  uuid,
  uuid,
  text,
  jsonb
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pos_sync_table_account(
  uuid,
  uuid,
  text,
  jsonb
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.pos_sync_operating_expense(
  uuid,
  uuid,
  text,
  jsonb
) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.pos_sync_table_account(
  uuid,
  uuid,
  text,
  jsonb
) TO anon, authenticated;
