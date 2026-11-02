# Agentes — SmooControl / Quantix Engineering Standards

Este repositorio adopta la revisión **0.1.3** del repositorio privado
`reySanchezDev/QuantixEngineeringStandar`, commit
`63d3a6bfc8f3a0db61979f97a2201e75e5c6985c`.

## Antes de modificar código o UI

1. Leer `rules.md` (reglas históricas específicas de este repositorio).
2. Leer `Documentation/Standards/UX_UI_STANDARD.md`.
3. Leer `Documentation/Standards/COMPONENT_CONTRACTS.md`.
4. Leer `Documentation/Standards/ENGINEERING_STANDARD.md`.
5. Leer `Documentation/Standards/SMOOCONTROL_RULES.md`.

Estas copias son una **revisión fijada** del estándar central; no se actualizan
automáticamente. Para adoptar una nueva versión hay que sincronizarlas
explícitamente con un commit y comprobar las diferencias. No editar aquí las
políticas universales sin ratificar el cambio en el repositorio central.

## Aplicación

- Máximo 300 líneas por archivo de código mantenido manualmente.
- Centralizar componentes, evitar etiquetas/espacios redundantes y truncamiento
  de datos; validar roles y autorizaciones reales.
- UX-038: mantener encabezados, acciones, filtros y pies de paginación en
  posiciones coherentes mediante componentes compartidos para todos los módulos.
- UX-039: asegurar legibilidad y contraste WCAG AA frente al fondo efectivo,
  incluidos temas estacionales, overlays y gradientes; verificar en todos los estados.
- Respetar separación Admin Supabase remoto / POS Drift local.
- Trabajar en `develop/backoffice-v2` hasta aprobación de integración.
- No alterar `main`, producción, migraciones o funciones del POS durante
  cambios visuales del Backoffice.
- Ejecutar `dart format`, `flutter analyze`, pruebas y verificación de UI antes
  de considerar una tarea terminada; si el ambiente carece de Flutter,
  declararlo explícitamente, sin fingir resultados.
