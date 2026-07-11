# Auditoria Admin Remoto

Fecha: 2026-07-06

## Regla Del Proyecto

Las pantallas administrativas leen y escriben directamente en Supabase. Drift,
repositorios locales y cola de sincronizacion quedan reservados para POS,
cache operativo del dispositivo y sincronizacion.

Cuando una pantalla admin guarda, edita o elimina datos, la operacion debe
terminar contra Supabase. Si luego se refresca una lista, ese refresco tambien
debe consultar Supabase. Admin no debe escribir local como confirmacion, ni
encolar cambios administrativos para subirlos despues.

## Implementacion Aplicada

- Se agrego `SupabaseAdminRepository` como repositorio remoto directo para
  catalogos/admin.
- Se agrego `SupabaseAdminExpensesRepository` para separar gastos admin del
  repositorio local usado por POS.
- La DI conecta las pantallas admin a repositorios remotos:
  - `CatalogBloc`
  - `ProductsBloc`
  - `ModifiersBloc`
  - `PaymentMethodsBloc`
  - `TablesBloc`
  - `ExpensesBloc`
  - `BusinessSettingsBloc`
  - `RolesBloc`
  - `UsersBloc`
  - `AuditLogBloc`
  - `SalesBloc`
- Las paginas admin directas tambien usan repositorios remotos:
  - `InventoryPage`
  - `PackagingPage`
  - `ProductsPage`
  - `ExchangeRatesPage`
  - `SalesPage`
  - `SaleDetailPage`
- Se removio `AdminDataRefreshService` de los BLoCs admin para evitar refrescos
  hacia cache local desde pantallas administrativas.
- `RolesBloc` y `UsersBloc` mantienen semilla local solo como compatibilidad de
  repositorios locales; la DI admin usa `seedDefaults: false`.

## Matriz Admin

| Modulo admin | Fuente de lectura final | Fuente de escritura final | Estado |
| --- | --- | --- | --- |
| Categorias | Supabase via `SupabaseAdminRepository` | Supabase via `SupabaseAdminRepository` | Alineado |
| Gestionar productos | Supabase via `SupabaseAdminRepository` | Supabase via `SupabaseAdminRepository` | Alineado |
| Gestionar inventario | Supabase via `SupabaseInventoryAdminReadService` | RPC batch remota via `SupabaseInventoryAdminWriteService` | Alineado |
| Gestionar empaque | Supabase via `SupabaseAdminRepository` | Supabase via `SupabaseAdminRepository`; compras por lote via RPC batch | Alineado |
| Modificadores POS admin | Supabase via `SupabaseAdminRepository` | Supabase via `SupabaseAdminRepository` | Alineado |
| Metodos de pago | Supabase via `SupabaseAdminRepository` | Supabase via `SupabaseAdminRepository` | Alineado |
| Mesas admin | Supabase via `SupabaseAdminRepository` | Supabase via `SupabaseAdminRepository` | Alineado |
| Ventas admin | Supabase via `SupabaseSalesAdminRepository` | Supabase via `SupabaseSalesAdminRepository` cuando aplique anulacion/admin | Alineado |
| Gastos admin | Supabase via `SupabaseAdminExpensesRepository` | Supabase via `SupabaseAdminExpensesRepository` | Alineado |
| Configuracion | Supabase via `SupabaseAdminRepository` | Supabase via `SupabaseAdminRepository` | Alineado |
| Tasa de cambio | Supabase via `SupabaseAdminRepository` | Supabase via `SupabaseAdminRepository` | Alineado |
| Roles | Supabase/RPC via `SupabaseAdminRepository` | Supabase/RPC via `SupabaseAdminRepository` | Alineado |
| Usuarios | Supabase/RPC via `SupabaseAdminRepository` | Supabase/RPC via `SupabaseAdminRepository` | Alineado |
| Auditoria | Supabase via `SupabaseAdminRepository` | Supabase via `SupabaseAdminRepository` | Alineado |

## Compras Por Lote

- Migracion agregada: `021_admin_inventory_batch_purchases.sql`.
- RPCs agregadas:
  - `app_register_inventory_purchase_batch`
  - `app_register_packaging_purchase_batch`
- Las RPCs validan restaurante, permiso `inventario.gestionar`, item activo,
  control de stock, cantidad positiva y costo unitario valido.
- La operacion es atomica: si una fila falla, Supabase revierte todo.
- `COSTO` es costo unitario y actualiza el costo actual del producto/empaque.
- La pantalla guarda solo filas con cantidad mayor que cero y refresca desde
  Supabase.

## Auditoria Estatica

Busqueda usada:

```powershell
rg -n "AdminDataRefreshService|remoteRefreshService" lib/features lib/core/di test -g "*.dart"
rg -n "serviceLocator<I[A-Za-z]+Repository>" lib/features -g "*.dart"
```

Resultado esperado:

- `AdminDataRefreshService` solo puede existir como servicio de sincronizacion
  heredado o pruebas propias del servicio, no inyectado en pantallas admin.
- `serviceLocator<I...Repository>` puede aparecer en POS porque POS opera local.
- El dashboard consulta permisos no-admin mediante `SupabaseAdminRepository`
  para no depender del repositorio local de roles.

## Limites Intencionales

- Los repositorios locales existentes no se eliminan porque POS los usa para
  operar offline.
- `AdminDataRefreshService` no se elimina porque puede seguir siendo util para
  sincronizacion/cache operativo, pero no debe conectarse a BLoCs admin.
- Las ediciones POS local-only siguen siendo locales:
  - nombre temporal visible de mesa en POS;
  - disponibilidad diaria de modificadores POS.
- POS ve los cambios administrativos solamente despues de sincronizar catalogos.

## Regla De Aceptacion Para Cambios Futuros

Un cambio administrativo queda aceptado solo si:

- carga inicial consulta Supabase;
- guardar/editar/eliminar llama Supabase directo;
- despues del guardado se recarga desde Supabase si la pantalla muestra lista;
- no escribe Drift;
- no usa cola de sincronizacion;
- no depende de `AdminDataRefreshService`;
- POS recibe el cambio solamente por sincronizacion de catalogos.
