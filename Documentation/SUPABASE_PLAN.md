# Plan Supabase - SmooControl

## Seguridad Operativa

- No tocar proyecto `MemberShip`.
- No enlazar CLI contra produccion existente.
- Crear proyecto remoto nuevo `SmooControl`.
- Confirmar `project-ref` antes de `db push`.
- No guardar secretos reales en el repositorio.
- `Recursos/VIGGO` es solo referencia de lectura.

## Local

- `supabase/config.toml`
- `supabase/migrations`
- `supabase/seed.sql`
- `001_initial_schema.sql` incluye disponibilidad POS y grupos de opciones de producto con indicador requerido/opcional.
- `sale_items` conserva `selected_options_label`.
- `roles` y `permissions` incluyen descripcion opcional para alinearse con mantenimiento local.
- `seed.sql` usa los mismos codigos de permisos que la app Flutter.
- `seed.sql` asigna permisos base a roles globales `admin`, `cashier` y `waiter`.
- Seeds globales con indices parciales usan `ON CONFLICT DO NOTHING` para evitar conflicto invalido.

## Remoto Pendiente

- Configurar Google Auth si se mantiene como proveedor de entrada.
- Reemplazar el usuario tecnico de sincronizacion por Auth por usuario real
  cuando se quiera trazabilidad remota por operador.
- Definir si `local_pos_open_ticket_lines` debe sincronizarse para trabajo
  multi-dispositivo o si queda como borrador local por tablet.

## Remoto Aplicado

- Proyecto remoto nuevo `SmooControl` creado en East US (Ohio).
- Project ref enlazado: `hexejdgbcmyiyqtvfihr`.
- Migracion `001_initial_schema.sql` aplicada.
- Migracion `002_sync_writes_and_exchange_rates.sql` aplicada.
- `seed.sql` aplicado con roles, permisos, metodos de pago base y categorias de gastos base.
- RLS habilitado en las 23 tablas publicas.
- RLS validado con usuario tecnico autenticado asociado al restaurante de
  produccion.
- `SupabaseSyncRemoteSender` conectado por DI y activable por `dart-define`.
- El archivo privado `Requerimiento/CredencialesSupabase.md` contiene los
  valores runtime para construir el APK conectado; no se versiona.

## Runtime APK Conectado

El APK conectado requiere:

- `SMOO_SUPABASE_URL`
- `SMOO_SUPABASE_PUBLISHABLE_KEY`
- `SMOO_RESTAURANT_ID`
- `SMOO_SUPABASE_AUTH_EMAIL`
- `SMOO_SUPABASE_AUTH_PASSWORD`

Regla temporal: la app sigue usando usuarios/PIN locales para operar, pero la
cola remota escribe en Supabase mediante un usuario tecnico Auth confirmado. En
una version posterior se debe cambiar a sesion Supabase por operador.

## Comandos Seguros

```powershell
supabase status
supabase migration list
```

Antes de cualquier comando remoto:

```powershell
supabase projects list
supabase migration list --linked
```
