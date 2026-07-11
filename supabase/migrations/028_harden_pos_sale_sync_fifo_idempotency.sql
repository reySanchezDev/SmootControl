-- Hardens POS sale synchronization without changing the public RPC contract.
-- The wrapper validates the sale payload before the legacy implementation runs
-- and rebuilds the remote line set after success so retries stay idempotent.
ALTER FUNCTION public.pos_sync_sale(uuid, uuid, text, jsonb)
RENAME TO pos_sync_sale_core_20260708;

CREATE OR REPLACE FUNCTION public.pos_sync_sale(
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
  sale_payload jsonb;
  sale_kind text;
  payload_total numeric;
  item_total numeric;
  item_count integer;
  item_ids uuid[];
  result jsonb;
  remote_sale_id uuid;
BEGIN
  sale_payload := p_payload -> 'sale';
  IF sale_payload IS NULL OR sale_payload = 'null'::jsonb THEN
    RAISE EXCEPTION 'Payload de venta POS invalido: falta encabezado'
      USING ERRCODE = '22023';
  END IF;

  sale_kind := COALESCE(NULLIF(sale_payload ->> 'sale_kind', ''), 'sale');
  payload_total := NULLIF(sale_payload ->> 'total_amount', '')::numeric;
  IF payload_total IS NULL OR payload_total < 0 THEN
    RAISE EXCEPTION 'Payload de venta POS invalido: total no valido'
      USING ERRCODE = '22023';
  END IF;

  SELECT
    COUNT(*)::integer,
    COALESCE(SUM((line.value ->> 'subtotal')::numeric), 0),
    ARRAY_AGG((line.value ->> 'id')::uuid)
  INTO item_count, item_total, item_ids
  FROM jsonb_array_elements(COALESCE(p_payload -> 'items', '[]'::jsonb)) AS line(value);

  IF sale_kind = 'sale' AND item_count = 0 THEN
    RAISE EXCEPTION 'Payload de venta POS invalido: venta sin detalle'
      USING ERRCODE = '22023';
  END IF;

  IF ABS(item_total - payload_total) > 0.009 THEN
    RAISE EXCEPTION
      'Payload de venta POS invalido: detalle (%) no cuadra con total (%)',
      item_total,
      payload_total
      USING ERRCODE = '22023';
  END IF;

  result := public.pos_sync_sale_core_20260708(
    p_restaurant_id,
    p_device_id,
    p_device_secret,
    p_payload
  );

  remote_sale_id := NULLIF(result ->> 'remote_id', '')::uuid;
  IF remote_sale_id IS NOT NULL THEN
    IF item_ids IS NULL OR ARRAY_LENGTH(item_ids, 1) IS NULL THEN
      DELETE FROM public.sale_items
       WHERE sale_id = remote_sale_id;
    ELSE
      DELETE FROM public.sale_items
       WHERE sale_id = remote_sale_id
         AND NOT (id = ANY(item_ids));
    END IF;
  END IF;

  RETURN result;
END;
$$;

REVOKE ALL ON FUNCTION public.pos_sync_sale(
  uuid,
  uuid,
  text,
  jsonb
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pos_sync_sale(
  uuid,
  uuid,
  text,
  jsonb
) TO anon, authenticated, service_role;

COMMENT ON FUNCTION public.pos_sync_sale(
  uuid,
  uuid,
  text,
  jsonb
) IS
  'Synchronizes one POS sale in FIFO-safe, idempotent form and validates sale totals before applying stock.';
