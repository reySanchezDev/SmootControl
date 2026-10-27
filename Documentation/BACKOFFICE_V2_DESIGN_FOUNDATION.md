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
