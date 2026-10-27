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
