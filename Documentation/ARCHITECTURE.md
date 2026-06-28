# Arquitectura - SmooControl

## Principios

- Flutter/Dart 100%.
- Feature-first en `lib/features`.
- Clean Architecture por feature.
- BLoC para estado.
- Repositorios por interfaz en dominio.
- Data implementa contratos de dominio.
- UI siempre usa Design System y l10n.

## Capas Por Feature

```text
lib/features/<feature>/
  domain/
    entities/
    repositories/
    services/
  data/
    models/
    datasources/
    repositories/
  presentation/
    bloc/
    pages/
    widgets/
```

## Dependencias Permitidas

```text
presentation -> bloc -> domain <- data
```

## Core Compartido

- `core/app`: app root.
- `core/design_system`: componentes visuales.
- `core/di`: registro de dependencias.
- `core/navigation`: rutas y generacion de pantallas.
- `core/responsive`: breakpoints y builders.
- `core/result`: resultado/falla comun para dominio y data.
- `core/theme`: tema base, `ColorScheme` y extensiones semanticas.

## Tema Y Paleta

- La paleta se centraliza en `core/theme`.
- `AppPalette` define la paleta oficial `Ivory Premium`.
- `AppTheme` define el `ColorScheme` base a partir de `AppPalette`.
- `AppSemanticColors` define colores de negocio/operacion que Material no cubre,
  por ejemplo estados de mesas, acciones de separacion y seleccion tactil.
- Las pantallas no deben usar `Color(0x...)` ni `Colors.*`; deben usar
  `Theme.of(context).colorScheme` o `context.semanticColors`.
- Al recibir una nueva paleta, se actualiza `AppTheme` y `AppSemanticColors`
  sin editar pantalla por pantalla.
- Paleta oficial actual:
  - Fondo principal: `#F8F4EE`.
  - Superficies, cards, paneles y dialogos: `#FFFDF9`.
  - Fondo secundario: `#EFE7DA`.
  - Texto principal: `#2B2622`.
  - Texto secundario: `#7A7168`.
  - Principal: `#C9A46A`.
  - Principal oscuro: `#A8824A`.
  - Acento elegante: `#B76E5D`.
  - Acento premium suave: `#D8B7A6`.
  - Bordes y divisores: `#DDD2C4`.
  - Error/peligro: `#9A3D4A`.
  - Exito/confirmacion: `#7C8B6B`.

## Dominio Inicial

- Catalogo: categorias y subcategorias.
- Productos: precio, costo y ganancia estimada.
- Metodos de pago: efectivo, referencia y disponibilidad.
- Tasas de cambio: tasa diaria por moneda para cobros extranjeros.
- Mesas: estado operativo.
- POS: separacion de cuentas por mesa.
- Ventas: venta completada/anulada y detalle en borrador.
- Caja: apertura/cierre diario.
- Gastos: categoria y gasto operativo.

## Data Local Inicial

Repositorios locales implementados:

- `CatalogRepository`
- `ProductsRepository`
- `PaymentMethodsRepository`
- `ExchangeRateRepository`
- `TablesRepository`
- `SalesRepository`
- `CashRegisterRepository`
- `ExpensesRepository`
- `SyncQueueRepository`

Todos implementan interfaces de dominio y devuelven `AppResult`.

## Sincronizacion

- `LocalSyncQueueDataSource` guarda operaciones pendientes en Drift/SQLite.
- `SyncQueueRepository` expone la cola mediante contrato de dominio.
- `SyncQueueProcessor` procesa la cola en orden FIFO y actualiza estados.
- `ISyncRemoteSender` separa el envio remoto de la cola local.
- `DisabledSyncRemoteSender` evita sincronizaciones falsas hasta crear Supabase remoto SmooControl.

## Acceso Y Permisos

- `IAuthRepository` define el contrato de autenticacion.
- `LocalAuthRepository` implementa autenticacion local offline por correo y PIN, crea el primer administrador cuando no existen usuarios con PIN y alimenta `CurrentOperatorService`.
- `DisabledAuthRepository` queda como referencia/fallback para escenarios donde Auth remoto aun no este configurado.
- `IRolesRepository` administra roles, permisos y asignaciones.
- `IUsersRepository` administra perfiles locales de usuario y puede actualizar el PIN almacenado como hash con salt.
- `AccessControlService` centraliza consultas de permisos por rol.
- `RouteAccessGuard` protege rutas por permisos, incluso si el usuario escribe la URL manualmente.
- El dashboard filtra acciones y modulos con el mismo mapa centralizado de permisos.
- Las pantallas no deben consultar permisos ad hoc; deben usar el servicio, `RouteAccessGuard` o BLoCs que dependan de el.

## BLoC Inicial

BLoCs implementados con estados explicitos de carga, datos y error:

- `CatalogBloc`
- `ProductsBloc`
- `PaymentMethodsBloc`
- `TablesBloc`
- `SalesBloc`
- `CashRegisterBloc`
- `ExpensesBloc`

## Validacion

- Registrar siempre la raiz local del proyecto con `mcp__dart.add_roots` antes de usar herramientas Dart MCP.
- Usar `mcp__dart.analyze_files` acotado a `lib` y `test`.
- Usar `mcp__dart.run_tests` acotado a `test`.
- Evitar formato/analisis amplio si aparecen carpetas externas de referencia dentro del workspace.
