# Auditoría de organización del repositorio — 2026-10-27

## Alcance y estado
- Base: `main` en `2700a49e1794a4ddf99d879dbc83bb7998510df9`.
- Rama de trabajo: `maintenance/repository-cleanup`.
- Inventario Git recursivo: 1331 entradas, consulta no truncada.
- Esta auditoría **no** constituye una certificación exhaustiva de archivos sin uso: requiere resolver referencias de código, generadores, Gradle, scripts, CI, recursos y despliegues locales.
- Sin ejecución de `flutter analyze`, `flutter test` ni builds desde GitHub.

## Clasificación de elementos de raíz

| Ruta | Decisión | Motivo / condición |
| --- | --- | --- |
| `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `l10n.yaml` | Mantener raíz | Convenciones y herramientas Flutter/Dart |
| `.gitignore`, `.metadata` | Mantener raíz | Metadatos del proyecto |
| `README.md` | Actualizado | Guía de entrada del proyecto |
| `android/`, `web/`, `lib/`, `test/`, `assets/` | Mantener | Estructura del proyecto |
| `tool/`, `supabase/` | Mantener | Scripts y migraciones |
| `comandos.md` | Reubicado | Contenido conservado en `Documentation/OPERATIONS_COMMANDS.md` |
| `Documentation/` | Mantener | Documentos técnicos; índice incorporado |
| `Requerimiento/` | Mantener hasta análisis de referencias | `tool/build_android_release.ps1` y `tool/build_web_release.ps1` apuntan a `Requerimiento/CredencialesSupabase.md` |
| `RequerimientoRefinado/` | Evaluar en otra fase | Fuente histórica; no se demostró duplicidad semántica exacta |
| `rules.md`, `.agente` | Mantener | Instrucciones de agentes y convención de desarrollo; `.agente` apunta a `rules.md` |
| `iconos/marcada.png` | Evaluar después | Antes de mover hay que verificar referencias a asset/iconos y empaquetado |
| `release/*.buildinfo.txt` | Evaluar después | Metadatos de compilación versionados que los scripts generan y que existen modificados en el equipo local |

## Cautelas verificadas
1. **No borrar `lib/core/database/app_database.g.dart` sin regeneración controlada.** Es código Drift generado y la compilación puede depender del archivo versionado.
2. **No borrar `web/sqlite3.wasm` ni `web/drift_worker.js`.** `tool/build_web_release.ps1` compila el worker y copia ambos recursos hacia `build/web`.
3. **No reubicar `Requerimiento/CredencialesSupabase.md` arbitrariamente.** Está ignorado en Git, pero los scripts de compilación lo buscan por su ruta actual.
4. **No eliminar `Requerimiento/mejoras.md` ni `Documentation/PROJECT_TRACKING.md` por tamaño.** Conservan contexto histórico de decisiones; cualquier archivado debe preservar el contenido.
5. **No eliminar `release/*.buildinfo.txt` desde remoto aún.** Git registra dichos archivos y el equipo local posee modificaciones no publicadas. Antes de dejar de rastrearlos hay que preservar las variantes locales y acordar el destino del historial.
6. **No ejecutar limpieza automática por extensión ni por antigüedad.** Que un archivo no esté importado en Dart no demuestra que sea prescindible.

## Ejecutado en esta fase
- `comandos.md` reubicado a `Documentation/OPERATIONS_COMMANDS.md`, conservando contenido.
- `README.md` actualizado para describir arquitectura, módulos y procedimientos.
- `Documentation/README.md` agregado como índice.
- Este documento registra el criterio y los pendientes.

## Pendiente antes de aprobar eliminaciones y grandes movimientos
- Buscar referencias exactas a cada archivo candidato en Dart, Markdown, YAML, PowerShell, Gradle y flujos de CI.
- Clasificar archivos generados: versionado requerido / reconstruible / artefacto distribuido.
- Revisar enlaces relativos de Markdown después de mover documentos.
- Ejecutar `flutter analyze`, `flutter test` y builds web/Android controlados en el entorno local.
- Registrar un manifiesto de archivos eliminados/movidos con justificación y mecanismo de recuperación.
- Revisar y preservar los `buildinfo` modificados localmente antes de dejarlos fuera del control de versiones.

## Restricciones
- `main` queda intacto mientras este PR esté en borrador.
- La limpieza no debe alterar reglas de negocio, esquema, ventas, caja, datos locales ni sincronización.
- Los cambios de estructura grandes deben ir en commits separados y ser verificables.

## Validación local reportada — 2026-10-27

Codex comprobó en la rama remota de mantenimiento:
- Flutter 3.41.7 / Dart 3.11.5.
- `flutter pub get`: correcto.
- `flutter analyze`: sin incidencias.
- `flutter test`: 300 pruebas aprobadas; advertencia no fatal de hit-test en prueba POS.
- `tool/build_web_release.ps1`: correcto; worker, WASM, HTML, manifest e iconos presentes. Se emitió advertencia de deprecación de `--pwa-strategy`.
- `flutter build apk --debug`: **no concluyente** por bloqueo prolongado en Gradle; se canceló.
- Se observó el archivo temporal local `android/.kotlin/sessions/*.salive`; la ruta `/android/.kotlin/` se añadió a `.gitignore` en esta rama. La exclusión Git **no borra** el residuo local.
- Los dos `release/*.buildinfo.txt` locales se conservaron sin cambios.

### Pendientes para otra fase
- Determinar uso real de `lib/core/config/app_build_info.dart`, `iconos/marcada.png`, `cupertino_icons` y `mocktail` antes de cualquier eliminación.
- Verificar compilación Android en un entorno Gradle estable; el bloqueo no demuestra fallo del código.
- Depurar localmente logs ignorados y residuo `.salive` solo después de comprobar que no pertenecen a procesos activos y sin borrar registros que se deseen conservar.
- Mantener las compilaciones de producción fuera del alcance de esta limpieza.
