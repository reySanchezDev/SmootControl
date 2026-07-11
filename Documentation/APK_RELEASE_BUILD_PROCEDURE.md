# Procedimiento Obligatorio Para Reconstruir El APK

## Problema Que Evita

SmooControl puede compilar un APK con:

```powershell
flutter build apk --release
```

pero ese APK queda incompleto para produccion porque no recibe las variables
`SMOO_SUPABASE_URL`, `SMOO_SUPABASE_PUBLISHABLE_KEY` y
`SMOO_RESTAURANT_ID`. El resultado es un APK que abre, pero en login o
inicializacion muestra mensajes como:

```text
Supabase no esta configurado para inicializar este dispositivo.
```

Ese comando directo esta prohibido para APKs entregables.

## Comando Correcto

Desde la raiz del proyecto:

```powershell
cd C:\Users\reyre\Aplicaciones\SmooControl
powershell -ExecutionPolicy Bypass -File .\tool\build_android_release.ps1
```

El script lee las credenciales desde:

```text
Requerimiento/CredencialesSupabase.md
```

y exige estas claves:

```text
SMOO_SUPABASE_URL=
SMOO_SUPABASE_PUBLISHABLE_KEY=
SMOO_RESTAURANT_ID=
```

El APK final queda en:

```text
release\SmooControl-produccion.apk
```

El script tambien deja evidencia en:

```text
release\SmooControl-produccion.buildinfo.txt
```

Ese archivo debe indicar:

- `InjectedDartDefines=SMOO_SUPABASE_URL,SMOO_SUPABASE_PUBLISHABLE_KEY,SMOO_RESTAURANT_ID`
- `InternetPermission=PRESENTE`
- `SqliteNativeLibrary=PRESENTE`
- `ForbiddenCommand=flutter build apk --release`
- package `com.smoocontrol.pos`
- `versionCode` y `versionName` esperados.

## Versionamiento Antes De Construir

Antes de cada APK que se va a instalar sobre otro APK ya entregado, aumentar
`pubspec.yaml`:

```yaml
version: X.Y.Z+N
```

Regla:

- `N` es el `versionCode`.
- `N` debe ser mayor que el ultimo APK instalado o entregado.
- No entregar dos APKs diferentes con el mismo `versionCode`.

Ejemplo:

```yaml
version: 0.1.18+23
```

## Validacion Despues Del Build

Ejecutar:

```powershell
$aapt = Get-ChildItem -Path "$env:LOCALAPPDATA\Android\Sdk\build-tools" `
  -Recurse -Filter aapt.exe |
  Sort-Object FullName -Descending |
  Select-Object -First 1

& $aapt.FullName dump permissions release\SmooControl-produccion.apk
& $aapt.FullName dump badging release\SmooControl-produccion.apk |
  Select-String -Pattern "package:|application-label:"
Get-Content release\SmooControl-produccion.buildinfo.txt
```

Debe verse:

```text
uses-permission: name='android.permission.INTERNET'
package: name='com.smoocontrol.pos' versionCode='...' versionName='...'
InjectedDartDefines=SMOO_SUPABASE_URL,SMOO_SUPABASE_PUBLISHABLE_KEY,SMOO_RESTAURANT_ID
InternetPermission=PRESENTE
SqliteNativeLibrary=PRESENTE
```

Tambien debe listar entradas similares a:

```text
lib/arm64-v8a/libsqlite3.so
lib/armeabi-v7a/libsqlite3.so
lib/x86_64/libsqlite3.so
```

Si falta `libsqlite3.so`, no entregar el APK. La base local Drift/SQLite puede
fallar en Android con mensajes como `Couldn't resolve native function
sqlite3_initialize`.

## Prueba Rapida En Tablet

Despues de instalar:

1. Abrir la app.
2. Confirmar que no aparece `Supabase no esta configurado...`.
3. Entrar en `Admin remoto` con usuario y clave.
4. Si la tablet esta limpia, confirmar que aparece flujo de inicializacion.
5. Entrar al POS con email/PIN restaurado.

## Checklist Para Codex

Antes de decir "APK reconstruido":

- confirmar que se uso `tool/build_android_release.ps1`;
- confirmar que no se uso `flutter build apk --release` directo;
- confirmar que existe `release\SmooControl-produccion.apk`;
- confirmar que existe `release\SmooControl-produccion.buildinfo.txt`;
- reportar `versionCode` y `versionName`;
- reportar `InternetPermission=PRESENTE`;
- reportar `SqliteNativeLibrary=PRESENTE`;
- si se entrega para instalar encima, confirmar que `versionCode` aumento.
