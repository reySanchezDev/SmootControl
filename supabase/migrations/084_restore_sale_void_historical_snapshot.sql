-- Restores the historical sale snapshot required by sale_voids.
-- Migration 019 replaced the POS sync sale-void INSERT from migration 010
-- and stopped supplying original_total_amount (NOT NULL since migration 001).
-- Use a small database invariant instead of rewriting the wrapped POS RPC chain.
CREATE OR REPLACE FUNCTION public.app_snapshot_sale_void_originals()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  original_sale record;
BEGIN
  SELECT
    s.total_amount,
    s.payment_method_id,
    s.payment_reference,
    s.cash_register_session_id
  INTO original_sale
  FROM public.sales AS s
  WHERE s.id = NEW.sale_id
    AND s.restaurant_id = NEW.restaurant_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'No existe venta original del restaurante para esta anulacion'
      USING ERRCODE = '23503';
  END IF;

  -- Server-authoritative values: never trust a client-supplied snapshot.
  NEW.original_total_amount := original_sale.total_amount;
  NEW.original_payment_method_id := original_sale.payment_method_id;
  NEW.original_payment_reference := original_sale.payment_reference;
  NEW.cash_register_session_id := original_sale.cash_register_session_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sale_voids_snapshot_originals_before_insert
  ON public.sale_voids;

CREATE TRIGGER sale_voids_snapshot_originals_before_insert
BEFORE INSERT ON public.sale_voids
FOR EACH ROW
EXECUTE FUNCTION public.app_snapshot_sale_void_originals();

COMMENT ON FUNCTION public.app_snapshot_sale_void_originals()
IS 'Rehydrates the immutable original sale totals, payment and cash session on void insertion. Prevents cross-restaurant sale references.';

REVOKE ALL ON FUNCTION public.app_snapshot_sale_void_originals()
  FROM PUBLIC;
