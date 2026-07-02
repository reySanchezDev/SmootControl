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
- Definir si `local_pos_open_ticket_lines` debe sincronizarse para trabajo
  multi-dispositivo o si queda como borrador local por tablet.

## Remoto Aplicado

- Proyecto remoto nuevo `SmooControl` creado en East US (Ohio).
- Project ref enlazado: `hexejdgbcmyiyqtvfihr`.
- Migracion `001_initial_schema.sql` aplicada.
- Migracion `002_sync_writes_and_exchange_rates.sql` aplicada.
- `seed.sql` aplicado con roles, permisos, metodos de pago base y categorias de gastos base.
- RLS habilitado en las 23 tablas publicas.
- RLS validado con sesion remota autenticado asociado al restaurante de
  produccion.
- `SupabaseSyncRemoteSender` conectado por DI y activable por `dart-define`.
- Migracion `010_pos_device_sync.sql` aplicada:
  - `pos_devices`
  - `register_pos_device`
  - `pos_sync_cash_register_session`
  - `pos_sync_sale`
- Migracion `011_pos_device_operational_sync.sql` aplicada:
  - `pos_sync_operating_expense`
  - `pos_sync_table_account`
- Migracion `012_pos_device_pgcrypto_search_path.sql` aplicada:
  - corrige `register_pos_device` y `assert_pos_device` para usar
    `extensions.digest(...)` de `pgcrypto`.
- Migracion `013_operational_user_fks_to_profiles.sql` aplicada:
  - caja, ventas, cuentas separadas, anulaciones, gastos y auditoria ahora
    referencian `public.profiles` como identidad operativa.
  - `pos_devices.created_by_user_id` permanece apuntando a `auth.users` porque
    representa al administrador remoto que autorizo el dispositivo.
- La sincronizacion POS de caja y ventas usa credencial tecnica de dispositivo,
  no sesion activa del administrador.
- El archivo privado `Requerimiento/CredencialesSupabase.md` contiene los
  valores runtime para construir el APK conectado; no se versiona.

## Runtime APK Conectado

El APK conectado requiere:

- `SMOO_SUPABASE_URL`
- `SMOO_SUPABASE_PUBLISHABLE_KEY`
- `SMOO_RESTAURANT_ID`

Regla actual: la app usa usuarios/PIN locales para operar el POS offline. La
cola remota de caja y ventas escribe en Supabase mediante dispositivo
autorizado y revocable. El administrador remoto se usa para inicializar,
restaurar y administrar datos online-first.

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

