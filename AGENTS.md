# Agentes — SmooControl / Quantix Engineering Standards

Este repositorio adopta la revisión **0.1.0** del repositorio privado
`reySanchezDev/QuantixEngineeringStandar`, commit
`a026ededa9f3c98f3ab493cc76b695af71e23df3`.

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
- Respetar separación Admin Supabase remoto / POS Drift local.
- Trabajar en `develop/backoffice-v2` hasta aprobación de integración.
- No alterar `main`, producción, migraciones o funciones del POS durante
  cambios visuales del Backoffice.
- Ejecutar `dart format`, `flutter analyze`, pruebas y verificación de UI antes
  de considerar una tarea terminada; si el ambiente carece de Flutter,
  declararlo explícitamente, sin fingir resultados.
