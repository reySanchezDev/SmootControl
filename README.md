# SmooControl

Sistema de administración y punto de venta para restaurante, implementado en Flutter/Dart y adaptado a la operación del establecimiento.

## Componentes

- **Backoffice:** administración, catálogos, personal, inventario, caja y reportes; sus operaciones administrativas utilizan Supabase.
- **POS:** operación táctil en Android con persistencia local Drift/SQLite y sincronización diferida.
- **Supabase:** esquema, políticas, migraciones y funciones remotas versionadas en `supabase/`.

## Estado de versiones

La versión del proyecto se declara en `pubspec.yaml`. No asumir que los cambios de esquema Supabase versionados ya fueron aplicados a producción: deben verificarse por separado.

## Estructura principal

| Directorio | Propósito |
| --- | --- |
| `lib/core/` | Infraestructura y componentes compartidos |
| `lib/features/` | Funcionalidades por dominio |
| `test/` | Pruebas automatizadas |
| `supabase/` | Migraciones y configuración SQL |
| `Documentation/` | Arquitectura, reglas, procedimientos y planes |
| `tool/` | Herramientas y scripts de compilación |
| `android/`, `web/` | Integración con cada plataforma |
| `assets/` | Recursos de la aplicación |

## Documentación

- [Índice completo de documentación](Documentation/README.md)
- [Arquitectura](Documentation/ARCHITECTURE.md)
- [Reglas de negocio](Documentation/BUSINESS_RULES.md)
- [Sincronización offline](Documentation/OFFLINE_SYNC.md)
- [Procedimiento de APK](Documentation/APK_RELEASE_BUILD_PROCEDURE.md)
- [Comandos operativos](Documentation/OPERATIONS_COMMANDS.md)
- [Auditoría de estabilidad de V1](Documentation/V1_PRODUCTION_STABILITY_AUDIT.md)
- [Reglas para agentes](rules.md)

## Validación

```bash
flutter pub get
flutter analyze
flutter test
```

Estos comandos no sustituyen las verificaciones operativas de producción.

## Compilaciones de entrega

**No utilizar directamente `flutter build apk --release` para generar el APK entregable.** La compilación de producción utiliza parámetros de configuración que deben inyectarse con el script aprobado. Los archivos de credenciales son locales, sensibles y no se versionan.

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\production_preflight.ps1
powershell -ExecutionPolicy Bypass -File .\tool\build_android_release.ps1
```

Para web, consultar [Comandos operativos](Documentation/OPERATIONS_COMMANDS.md).

## Política de cambios

El sistema está en uso real. No eliminar archivos ni alterar flujos de ventas, caja, sincronización o migraciones sin verificar dependencias y disponer de validación previa. Las mejoras estructurales deben probarse antes de integrarlas en `main`.
