ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS pin_salt text,
  ADD COLUMN IF NOT EXISTS pin_hash text,
  ADD COLUMN IF NOT EXISTS is_pos_user boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.profiles.pin_salt IS
  'Salt del PIN local usado por el POS offline. No guarda el PIN plano.';

COMMENT ON COLUMN public.profiles.pin_hash IS
  'Hash del PIN local usado por el POS offline. Permite restaurar login local.';

COMMENT ON COLUMN public.profiles.is_pos_user IS
  'Indica si el usuario entra directamente al flujo operativo POS.';
