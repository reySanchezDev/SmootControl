# Comandos Operativos Del Sitio Web

Estos comandos se ejecutan desde la raiz del proyecto:

```powershell
cd C:\Users\reyre\Aplicaciones\SmooControl
```

## Construir El Sitio En Modo Release

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1
```

Este script genera `build\web`, compila `web\drift_worker.dart` y copia los
assets necesarios de Drift/SQLite (`sqlite3.wasm` y `drift_worker.js`).

## Reconstruir El APK Release Correctamente

Antes de construir un APK que se va a instalar en tablet/telefono, subir el
`versionCode` en `pubspec.yaml`:

```yaml
version: 0.1.18+23
```

Luego construir solo con:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\build_android_release.ps1
```

Salida esperada:

```text
release\SmooControl-produccion.apk
release\SmooControl-produccion.buildinfo.txt
```

No usar para APK entregable:

```powershell
flutter build apk --release
```

Ese comando directo no inyecta `SMOO_SUPABASE_URL`,
`SMOO_SUPABASE_PUBLISHABLE_KEY` ni `SMOO_RESTAURANT_ID`. El APK puede abrir,
pero falla login/inicializacion con mensajes como:

```text
Supabase no esta configurado para inicializar este dispositivo.
```

Validar despues del build:

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

Debe verse `InternetPermission=PRESENTE` y:

```text
InjectedDartDefines=SMOO_SUPABASE_URL,SMOO_SUPABASE_PUBLISHABLE_KEY,SMOO_RESTAURANT_ID
SqliteNativeLibrary=PRESENTE
```

Tambien deben existir entradas `libsqlite3.so` dentro del APK. Si faltan, no
instalar ese APK porque puede fallar Drift/SQLite en Android.

## Enlistar Instancias Levantadas

Ver que proceso esta escuchando en el puerto 8080:

```powershell
Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue |
  Select-Object LocalAddress,LocalPort,OwningProcess
```

Ver el comando exacto de los servidores Python levantados:

```powershell
Get-CimInstance Win32_Process |
  Where-Object { $_.CommandLine -like '*http.server*' } |
  Select-Object ProcessId,CommandLine
```

## Matar Instancias Levantadas

Matar el proceso que escucha en el puerto 8080:

```powershell
$pids = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue |
  Select-Object -ExpandProperty OwningProcess -Unique

$pids | ForEach-Object { Stop-Process -Id $_ -Force }
```

Matar todos los servidores `python -m http.server`:

```powershell
Get-CimInstance Win32_Process |
  Where-Object { $_.CommandLine -like '*http.server*' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
```

## Levantar El Sitio Nuevamente

Levantar el sitio release solo para esta PC:

```powershell
Start-Process -FilePath python `
  -ArgumentList @('-m','http.server','8080','--bind','127.0.0.1') `
  -WorkingDirectory (Resolve-Path '.\build\web') `
  -WindowStyle Hidden
```

Abrir en el navegador:

```powershell
Start-Process http://127.0.0.1:8080/
```

## Levantar Para Acceso Desde Otro Equipo En La Red

Usar este modo solo si se necesita abrir el sitio desde otro dispositivo de la
misma red:

```powershell
Start-Process -FilePath python `
  -ArgumentList @('-m','http.server','8080','--bind','0.0.0.0') `
  -WorkingDirectory (Resolve-Path '.\build\web') `
  -WindowStyle Hidden
```

Consultar la IP local del equipo:

```powershell
Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object { $_.IPAddress -notlike '169.254*' -and $_.IPAddress -ne '127.0.0.1' } |
  Select-Object InterfaceAlias,IPAddress
```

Luego abrir desde otro dispositivo:

```text
http://IP_DEL_EQUIPO:8080/
```

## Verificar Que Esta Respondiendo

```powershell
(Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8080/).StatusCode
```

Debe responder:

```text
200
```
