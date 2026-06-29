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

- Cerrar `Documentation/SUPABASE_READINESS_AUDIT.md` prioridad alta restante.
- Configurar Google Auth.
- Reemplazar `DisabledAuthRepository` por repositorio Supabase Auth.
- Conectar `SupabaseSyncRemoteSender`.
- Validar RLS.

## Remoto Aplicado

- Proyecto remoto nuevo `SmooControl` creado en East US (Ohio).
- Project ref enlazado: `hexejdgbcmyiyqtvfihr`.
- Migracion `001_initial_schema.sql` aplicada.
- `seed.sql` aplicado con roles, permisos, metodos de pago base y categorias de gastos base.
- RLS habilitado en las 23 tablas publicas.

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
