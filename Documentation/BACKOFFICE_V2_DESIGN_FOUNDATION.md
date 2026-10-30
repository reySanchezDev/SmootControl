# Backoffice V2 — Diseño e integración progresiva

## Decisión de producto
Identidad: Executive Ivory. Navegación: sidebar contraíble con control central curvo inspirado en el patrón de VIGGO, y futuro espacio de trabajo multipestaña. Aplicación: Backoffice administrativo únicamente; POS intacto.

## Primera entrega en rama develop/backoffice-v2
- `lib/core/design_system/navigation/backoffice_sidebar.dart`: componente aislado, sin dependencias sobre VIGGO, no integrado aún al router.
- `test/core/design_system/navigation/backoffice_sidebar_test.dart`: prueba de expansión, contracción y selección.
- Anchos parametrizados: 248 px abierto, 64 px cerrado y saliente de 20 px.
- Animación 240 ms, tooltip y etiquetas semánticas.
- Permisos: el consumidor debe suministrar exclusivamente los elementos permitidos; el componente no concede acceso.
- Estado: controlado externamente para conectar en el futuro a preferencias y workspace.

## Pendiente antes de integrar a las pantallas
1. Ejecutar `flutter analyze` y `flutter test test/core/design_system/navigation/backoffice_sidebar_test.dart` localmente.
2. Auditar la navegación administrativa actual, accesos POS, rutas y guards para montar un Shell de Backoffice sin cambiar su autorización.
3. Implementar tabs con preservación de estado, cambios sin guardar y política de cierre; conservar rutas y controles de acceso.
4. Ampliar tokens y catálogo de componentes Executive Ivory sin duplicar `AppTheme`.
5. Validar responsive, teclado, foco, zoom y accesibilidad.
6. Comparar capturas antes/después y aprobar visualmente antes de migrar módulos.

**No modificar producción ni ejecutar migraciones.** Ninguna ruta del sistema consume todavía el nuevo sidebar. Los cambios permanecen aislados hasta validar y aprobar la integración.

## Segunda entrega — Workspace multipestaña aislado
- `lib/core/design_system/navigation/backoffice_workspace.dart`: BackofficeWorkspace con barra de pestañas, navegación hacia módulos ya abiertos, cierre opcional, y conservación de estado montado por `IndexedStack`.
- `test/core/design_system/navigation/backoffice_workspace_test.dart`: pruebas iniciales de apertura/cierre y veto de cierre.
- El consumidor inyecta destinos permitidos y un `pageBuilder` que **debe envolver la página en los guards existentes**. No conectar directamente páginas sin permisos.
- `onCloseRequested` ofrece un veto asíncrono; cada formulario debe implementar su chequeo de cambios no guardados antes de usarse en producción.
- Sin integración en el router y sin cambios en POS; este avance requiere pruebas locales de formato, análisis, widgets y revisión visual.
- Estado de menú y tabs todavía efímero; persistencia, deep links y restauración se implementarán en una fase posterior con reglas de seguridad.

## Integración directa al Backoffice (2026-10-27)
- Usuarios autenticados no-POS ahora entran en `BackofficeHomePage`, que aloja `BackofficeWorkspace` y módulos administrativos reales mediante `guardedBackofficePage`. POS permanece bajo su flujo original.
- Sidebar filtra destinos por permisos de rol; cada pestaña conserva también `RouteAccessGuard` y `AdminOnlineGuard` en su pantalla. Carga de permisos fallida bloquea el workspace.
- Se añade cerrar sesión al encabezado global.
- No se fusiona a main hasta compilar, probar autorización y revisar navegación. Navegación interna existente mediante Navigator.pushNamed puede seguir abriendo pantallas a nivel superior hasta migrarla al gestor de pestañas; no confundir con integración completa.
- Cierre de pestañas no puede proteger cambios no guardados hasta que cada formulario aporte un validador.
- No hay cambios de esquema o de datos.

## Executive Ivory — Primera migración funcional de Productos
- `lib/core/theme/backoffice_theme.dart`: tokens semánticos administrativos y configuración Material 3 exclusivamente bajo el Backoffice, evitando cambios accidentales de estilo en el POS.
- `lib/core/design_system/backoffice_data_table.dart`: tabla compartida con encabezados, filas y desplazamiento horizontal para columnas amplias; estilos derivados del tema.
- `lib/features/products/presentation/pages/backoffice_products_table.dart`: tabla de productos a partir del estado BLoC existente; búsqueda local, filtro de activos, categorías, precio, disponibilidad POS, seguimiento de inventario, editar y desactivar.
- `ProductsPage` conserva el listado compacto para anchuras menores a 1024 px y sus diálogos, persistencia, eventos BLoC y reglas de negocio originales.
- `test/core/design_system/backoffice_data_table_test.dart`: prueba del componente compartido.
- No se agregaron endpoints, migraciones, cambios de esquema ni capacidades de negocio ficticias.

### Verificación necesaria antes de integrar a main
Ejecutar `dart format` de todos los archivos Dart modificados, `flutter analyze`, `flutter test` y el build Web oficial. Validar que las páginas administrativas reales están visibles y autorizadas en 8081; confirmar funcionamiento de crear/editar/desactivar con datos de prueba autorizados, sin operaciones destructivas de producción. No fusionar a main todavía.

## Pantalla patrón Productos — revisión visual pendiente (29 octubre 2026)
- Desktop (>=1024px): cabecera única Productos con acción explícita Nuevo producto; cuatro contadores basados en la colección cargada (Total, Activos, En POS, Con inventario).
- Filtros funcionales: texto, estado, categoría, disponibilidad POS, control de inventario; botón Limpiar aparece solo cuando corresponde. Conteo de resultados sin ambigüedades.
- La tabla compartida fija las columnas encabezado y desplaza las filas en un viewport vertical propio; desplazamiento horizontal compartido garantiza alineación. Filas construidas a demanda.
- Se conserva el listado móvil y las operaciones BLoC/dialog existentes; no hay nuevas operaciones de escritura.
- Esta propuesta no es patrón aprobado aún: requiere compilación, revisión visual del dueño y sus cambios antes de aplicarla a otros módulos. No ejecutar otras migraciones administrativas todavía.

## Productos — Boceto visual aprobado (29/10/2026)
- Referencia: propuesta Executive Ivory aprobada por el usuario, con **fotografías ilustrativas expresamente excluidas**.
- Cabecera administrativa con una única acción Nuevo producto; KPIs compactados, sin texto de relleno.
- Tabla compacta: 42 px por fila y 38 px de encabezado anclado; indicadores de estado, POS e inventario con chips discretos; acciones existentes de edición y desactivación.
- Paginación local funcional de 10, 15, 25 o 50 registros por página, con anterior/siguiente y rango visible. Sin nuevas operaciones de servidor.
- Se conservan datos reales y flujos previos de Product BLoC y diálogos; no añadir imágenes ni funcionalidades inventadas.
- **Pendiente:** sincronización, dart format, flutter analyze, pruebas y build en el equipo de Codex; revisión visual del usuario antes de aplicar patrón a otras pantallas.

## Corrección de UX de Productos — observaciones de captura 29/10/2026
- Retirados cuatro contadores superiores del módulo Productos para aprovechar el área operativa. No duplicar información que figura en filtros o paginador.
- Eliminado «N de N productos» sobre tabla; paginador inferior conserva rango y total.
- Buscador ampliado a 380 px; encabezados ordenables sobre datos filtrados (nombre, categoría, precio, estado, disponibilidad POS e inventario; acciones no ordenables), con ascendente/descendente y paginación reiniciada al ordenar.
- Tablas: corregida la diferencia entre ancho del contenedor y ancho de columnas escalando todas las columnas en igual proporción. Header y cuerpo comparten anchuras efectivas exactas y el header queda anclado.
- Filtro de categoría sincroniza su valor al limpiar.
- No se añadieron fotos, selección múltiple, acciones masivas ni funcionalidades ficticias. No ampliar a otras pantallas antes de aprobación visual.
- Pendiente exclusivamente de Codex: dart format, flutter analyze, flutter test y compilación/revisión real en 8081. No se declara validación ejecutada desde GitHub.
