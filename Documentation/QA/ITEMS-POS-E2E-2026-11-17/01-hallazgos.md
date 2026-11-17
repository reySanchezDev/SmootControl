# Hallazgos

## H-001 — El POS Flutter no consume todavía el catálogo canónico

- Severidad: crítica.
- Reproducción: `SupabaseCatalogPullService` solicita la tabla `products` y
  aplica los datos a `localProducts`.
- Evidencia de código: `lib/features/sync/data/datasources/supabase_catalog_pull_service.dart`
  y `supabase_catalog_pull_service_catalog_part.dart`.
- Evidencia SQL: `public.pos_pull_item_catalog_v2(uuid, uuid, text)` existe y
  devuelve `items`, pero no está conectado al camino operativo de pull.
- Impacto: un item creado o editado en Backoffice puede no aparecer en POS.

## H-002 — Las ventas conservan el contrato `product_id`/`productId`

- Severidad: crítica.
- Reproducción: `sales_repository_sync_support.dart` serializa `productId`;
  `supabase_sync_remote_sender_sales_part.dart` lo convierte a `product_id` y
  usa el mismo valor como `product_code`.
- Impacto: no existe garantía de que el identificador corresponda al maestro
  `items`, al código comercial o a una fila vigente.

## H-003 — La sincronización remota de venta sigue en la función legada

- Severidad: crítica.
- Evidencia SQL: existe `public.pos_sync_sale(uuid, uuid, text, jsonb)` y su
  cadena de wrappers históricos; no existe `public.pos_sync_sale_v2`.
- Impacto: venta, stock, recetas, anulaciones e idempotencia no tienen todavía
  un contrato único basado en `item_id`.

## H-004 — No es segura la eliminación inmediata de `products`

- Severidad: crítica.
- Evidencia: hay referencias en Flutter, migraciones, funciones SQL y objetos
  relacionados (`product_modifier_groups`, `product_recipe_lines`,
  `product_packaging_rules`, entre otros).
- Decisión: no eliminar hasta completar la migración funcional y la matriz de
  dependencias.

## H-005 — La suite amplia no pudo certificarse por el entorno

- Severidad: media.
- Evidencia: Flutter encontró `FileSystemException` por espacio insuficiente al
  compilar artefactos temporales; el set no debe reportarse como aprobado.
- Acción: limpiar solo temporales de build permitidos y repetir pruebas, sin
  tocar datos del laboratorio.

## H-006 — El runner desechable de pruebas no pudo descargar PostgreSQL

- Severidad: media.
- Evidencia: Docker Hub devolvió `TLS handshake failure` al intentar descargar
  `postgres:16`.
- Acción: usar el Supabase Docker local ya existente para pruebas de integración
  y dejar el runner desechable como prueba adicional cuando la red lo permita.

