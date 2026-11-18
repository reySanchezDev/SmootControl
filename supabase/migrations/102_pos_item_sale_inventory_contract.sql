-- Canonical item_id contract for POS sales and inventory movements.
-- Legacy product_id remains nullable only for historical compatibility.
BEGIN;

ALTER TABLE public.sale_items
  ADD COLUMN IF NOT EXISTS item_id uuid REFERENCES public.items(id);

ALTER TABLE public.inventory_stock
  ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid(),
  ADD COLUMN IF NOT EXISTS item_id uuid REFERENCES public.items(id);

ALTER TABLE public.inventory_stock DROP CONSTRAINT IF EXISTS inventory_stock_pkey;

UPDATE public.inventory_stock
SET id = gen_random_uuid()
WHERE id IS NULL;

ALTER TABLE public.inventory_stock
  ALTER COLUMN id SET NOT NULL,
  ALTER COLUMN product_id DROP NOT NULL;

ALTER TABLE public.inventory_movements
  ADD COLUMN IF NOT EXISTS item_id uuid REFERENCES public.items(id),
  ALTER COLUMN product_id DROP NOT NULL;

ALTER TABLE public.inventory_stock ADD CONSTRAINT inventory_stock_pkey PRIMARY KEY (id);
CREATE UNIQUE INDEX IF NOT EXISTS inventory_stock_restaurant_product_unique
  ON public.inventory_stock (restaurant_id, product_id);
CREATE UNIQUE INDEX IF NOT EXISTS inventory_stock_restaurant_item_unique
  ON public.inventory_stock (restaurant_id, item_id);

UPDATE public.sale_items AS s
SET item_id = s.product_id
WHERE s.item_id IS NULL
  AND s.product_id IS NOT NULL
  AND EXISTS (SELECT 1 FROM public.items i WHERE i.id = s.product_id);

UPDATE public.inventory_stock AS s
SET item_id = s.product_id
WHERE s.item_id IS NULL
  AND s.product_id IS NOT NULL
  AND EXISTS (SELECT 1 FROM public.items i WHERE i.id = s.product_id);

UPDATE public.inventory_movements AS m
SET item_id = m.product_id
WHERE m.item_id IS NULL
  AND m.product_id IS NOT NULL
  AND EXISTS (SELECT 1 FROM public.items i WHERE i.id = m.product_id);

CREATE OR REPLACE FUNCTION public.pos_sync_sale_v2(
  p_restaurant_id uuid,
  p_device_id uuid,
  p_device_secret text,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  line jsonb;
  movement jsonb;
  normalized jsonb := p_payload;
  legacy_lines jsonb := '[]'::jsonb;
  legacy_movements jsonb := '[]'::jsonb;
  v_item_id uuid;
  v_sale_id uuid;
  result jsonb;
  current_quantity numeric;
  next_quantity numeric;
  reversal_id text;
BEGIN
  PERFORM public.assert_pos_device(
    p_restaurant_id, p_device_id, p_device_secret
  );

  FOR line IN SELECT value FROM jsonb_array_elements(
    COALESCE(p_payload -> 'items', '[]'::jsonb)
  ) LOOP
    v_item_id := NULLIF(
      COALESCE(line ->> 'item_id', line ->> 'product_id'), ''
    )::uuid;
    IF v_item_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.products p
      WHERE p.id = v_item_id AND p.restaurant_id = p_restaurant_id
    ) THEN
      legacy_lines := legacy_lines || jsonb_set(
        line, '{product_id}', to_jsonb(v_item_id::text), true
      );
    ELSE
      -- The historical core accepts a nullable product_id. The canonical
      -- identity is attached immediately after the idempotent core returns.
      legacy_lines := legacy_lines || jsonb_set(
        line, '{product_id}', 'null'::jsonb, true
      );
    END IF;
  END LOOP;

  FOR movement IN SELECT value FROM jsonb_array_elements(
    COALESCE(p_payload -> 'inventory_movements', '[]'::jsonb)
  ) LOOP
    v_item_id := NULLIF(
      COALESCE(movement ->> 'item_id', movement ->> 'product_id'), ''
    )::uuid;
    IF v_item_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.products p
      WHERE p.id = v_item_id AND p.restaurant_id = p_restaurant_id
    ) THEN
      legacy_movements := legacy_movements || jsonb_set(
        movement, '{product_id}', to_jsonb(v_item_id::text), true
      );
    END IF;
  END LOOP;

  normalized := jsonb_set(normalized, '{items}', legacy_lines, true);
  normalized := jsonb_set(
    normalized, '{inventory_movements}', legacy_movements, true
  );

  result := public.pos_sync_sale_device_cash_guard_base_20260721(
    p_restaurant_id, p_device_id, p_device_secret, normalized
  );
  v_sale_id := NULLIF(result ->> 'remote_id', '')::uuid;

  IF v_sale_id IS NULL THEN
    RETURN result;
  END IF;

  UPDATE public.sale_items AS stored
  SET item_id = NULLIF(line.value ->> 'item_id', '')::uuid
  FROM jsonb_array_elements(
    COALESCE(p_payload -> 'items', '[]'::jsonb)
  ) AS line(value)
  WHERE stored.id = (line.value ->> 'id')::uuid
    AND stored.sale_id = v_sale_id;

  FOR movement IN SELECT value FROM jsonb_array_elements(
    COALESCE(p_payload -> 'inventory_movements', '[]'::jsonb)
  ) LOOP
    v_item_id := NULLIF(
      COALESCE(movement ->> 'item_id', movement ->> 'product_id'), ''
    )::uuid;
    IF v_item_id IS NULL OR EXISTS (
      SELECT 1 FROM public.products p
      WHERE p.id = v_item_id AND p.restaurant_id = p_restaurant_id
    ) THEN
      CONTINUE;
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM public.inventory_movements
      WHERE id = movement ->> 'id'
    ) THEN
      INSERT INTO public.inventory_stock(
        restaurant_id, product_id, item_id, quantity_on_hand
      ) VALUES (p_restaurant_id, NULL, v_item_id, 0)
      ON CONFLICT (restaurant_id, item_id) DO NOTHING;

      SELECT s.quantity_on_hand INTO current_quantity
      FROM public.inventory_stock AS s
      WHERE s.restaurant_id = p_restaurant_id AND s.item_id = v_item_id
      FOR UPDATE;
      next_quantity := current_quantity +
        (movement ->> 'quantity_delta')::numeric;
      IF next_quantity < 0 THEN
        RAISE EXCEPTION 'Stock insuficiente para item canónico'
          USING ERRCODE = '23514';
      END IF;

      INSERT INTO public.inventory_movements(
        id, restaurant_id, product_id, item_id, movement_type,
        quantity_delta, reference_type, reference_id, user_id, notes,
        created_at
      ) VALUES (
        movement ->> 'id', p_restaurant_id, NULL, v_item_id,
        movement ->> 'movement_type',
        (movement ->> 'quantity_delta')::numeric,
        movement ->> 'reference_type', v_sale_id::text,
        movement ->> 'user_id', movement ->> 'notes',
        COALESCE(NULLIF(movement ->> 'created_at', '')::timestamptz, now())
      );

      UPDATE public.inventory_stock AS s
      SET quantity_on_hand = next_quantity, updated_at = now()
      WHERE s.restaurant_id = p_restaurant_id AND s.item_id = v_item_id;
    END IF;
  END LOOP;

  IF COALESCE(p_payload -> 'void', '{}'::jsonb) <> '{}'::jsonb OR
     COALESCE(p_payload -> 'sale' ->> 'status', '') = 'voided' THEN
    FOR movement IN
      SELECT to_jsonb(m) FROM public.inventory_movements m
      WHERE m.restaurant_id = p_restaurant_id
        AND m.reference_id = v_sale_id::text
        AND m.item_id IS NOT NULL
        AND m.movement_type = 'sale'
    LOOP
      reversal_id := 'void:' || movement ->> 'id';
      IF NOT EXISTS (
        SELECT 1 FROM public.inventory_movements WHERE id = reversal_id
      ) THEN
        UPDATE public.inventory_stock
        SET quantity_on_hand = quantity_on_hand -
              (movement ->> 'quantity_delta')::numeric,
            updated_at = now()
        WHERE restaurant_id = p_restaurant_id
          AND item_id = (movement ->> 'item_id')::uuid;

        INSERT INTO public.inventory_movements(
          id, restaurant_id, product_id, item_id, movement_type,
          quantity_delta, reference_type, reference_id, notes
        ) VALUES (
          reversal_id, p_restaurant_id, NULL,
          (movement ->> 'item_id')::uuid, 'sale_void',
          -((movement ->> 'quantity_delta')::numeric),
          'sale_void', v_sale_id::text, 'Reversión de venta POS'
        );
      END IF;
    END LOOP;
  END IF;

  RETURN result;
END;
$$;

REVOKE ALL ON FUNCTION public.pos_sync_sale_v2(uuid, uuid, text, jsonb)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pos_sync_sale_v2(uuid, uuid, text, jsonb)
  TO anon, authenticated, service_role;

CREATE OR REPLACE VIEW public.item_stock_balances
WITH (security_invoker = true)
AS
  SELECT i.id AS item_id, s.restaurant_id,
         s.quantity_on_hand::numeric(18,6) AS quantity_on_hand,
         'product'::text AS ledger_source, s.updated_at
  FROM public.inventory_stock s
  JOIN public.items i ON i.id = COALESCE(s.item_id, s.product_id)
    AND i.restaurant_id = s.restaurant_id
  UNION ALL
  SELECT i.id AS item_id, s.restaurant_id,
         s.quantity_on_hand::numeric(18,6) AS quantity_on_hand,
         'packaging'::text AS ledger_source, s.updated_at
  FROM public.packaging_stock s
  JOIN public.items i ON i.id = s.packaging_item_id
    AND i.restaurant_id = s.restaurant_id
    AND i.source_kind = 'packaging';

CREATE OR REPLACE VIEW public.item_ledger_entries
WITH (security_invoker = true)
AS
  SELECT i.id AS item_id, m.restaurant_id,
         m.id AS movement_id, m.movement_type,
         m.quantity_delta::numeric(18,6) AS quantity_delta,
         'product'::text AS ledger_source, m.reference_type,
         m.reference_id, m.created_at
  FROM public.inventory_movements m
  JOIN public.items i ON i.id = COALESCE(m.item_id, m.product_id)
    AND i.restaurant_id = m.restaurant_id
  UNION ALL
  SELECT i.id AS item_id, m.restaurant_id,
         m.id AS movement_id, m.movement_type,
         m.quantity_delta::numeric(18,6) AS quantity_delta,
         'packaging'::text AS ledger_source, m.reference_type,
         m.reference_id, m.created_at
  FROM public.packaging_movements m
  JOIN public.items i ON i.id = m.packaging_item_id
    AND i.restaurant_id = m.restaurant_id
    AND i.source_kind = 'packaging';

COMMIT;
