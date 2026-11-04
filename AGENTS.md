# Agentes — SmooControl / Quantix Engineering Standards

Este repositorio adopta la revisión **0.1.5** del repositorio privado
`reySanchezDev/QuantixEngineeringStandar`, commit
`eb5bf0057c01a45382b2a0a8f7cc4b03cdfb66cf`.

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
- UX-040: las operaciones se presentan con texto preciso y visible; no ocultar
  acciones bajo «Más», «…», «Opciones» ni iconos sin etiqueta. Mantener
  legibilidad responsive y permisos; no introducir agrupaciones ambiguas.
- SMO-009: en catálogos administrativos usar fila seleccionada y botonera
  superior fija; sin columna «Acciones». Deshabilitar comandos sin selección
  o permiso y no cambiar modos App/POS ni Tableta.
- Respetar separación Admin Supabase remoto / POS Drift local.
- Trabajar en `develop/backoffice-v2` hasta aprobación de integración.
- No alterar `main`, producción, migraciones o funciones del POS durante
  cambios visuales del Backoffice.
- Ejecutar `dart format`, `flutter analyze`, pruebas y verificación de UI antes
  de considerar una tarea terminada; si el ambiente carece de Flutter,
  declararlo explícitamente, sin fingir resultados.

## Build Web / preview con Supabase (obligatorio para Codex)

- **Usar siempre** `tool/build_web_release.ps1` para generar el Backoffice Web, nunca un `flutter build web` suelto ni un build sin `--dart-define`.
- El script exige `SMOO_SUPABASE_URL`, `SMOO_SUPABASE_PUBLISHABLE_KEY` y `SMOO_RESTAURANT_ID`. Si falta alguna, aborta **antes** de limpiar/compilar. Un HTTP 200 no demuestra que la autenticación esté configurada.
- El archivo `Requerimiento/CredencialesSupabase.md` permanece fuera del control de versiones y debe usarse sin copiarlo ni exponer su contenido. Al compilar desde `SmooControl-stabilization-latest`, el script puede reutilizar automáticamente el archivo del worktree hermano `SmooControl-backoffice-stabilization-integration`, si existe. Alternativamente usar `-CredentialsPath "RUTA_LOCAL"` o la variable `SMOO_CREDENTIALS_PATH` para declarar una ubicación estable en la máquina.
- **Nunca** añadir secretos a Git, logs, prompts ni capturas. Las claves de tipo service-role/secret **no deben** usarse en cliente Web; solo la clave publicable destinada al navegador.
- Reemplazar `8081` solo si el build válido termina con éxito. Verificar además que el inicio de sesión remoto esté configurado, no únicamente que los archivos respondan HTTP 200.
- No alterar `8080`, `main`, producción ni el worktree original para preparar el preview.
