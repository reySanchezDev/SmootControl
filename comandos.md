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
