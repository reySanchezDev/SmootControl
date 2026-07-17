-- Adds pound and keeps measurement units manageable as a remote catalog.

INSERT INTO public.measurement_units (
  restaurant_id,
  code,
  name,
  unit_group,
  base_factor
)
VALUES (NULL, 'lb', 'Libra', 'mass', 453.59237)
ON CONFLICT DO NOTHING;

