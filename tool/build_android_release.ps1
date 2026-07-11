param(
  [string]$OutputName = "SmooControl-produccion.apk",
  [string]$CredentialsPath = "Requerimiento/CredencialesSupabase.md"
)

$ErrorActionPreference = "Stop"

# IMPORTANT:
# Do not replace this script with a raw `flutter build apk --release`.
# SmooControl needs Supabase and restaurant values injected through
# --dart-define. A raw Flutter build compiles, but the APK cannot initialize or
# sign in against Supabase.

if (-not (Test-Path $CredentialsPath)) {
  throw "No se encontro $CredentialsPath"
}

$requiredKeys = @(
  "SMOO_SUPABASE_URL",
  "SMOO_SUPABASE_PUBLISHABLE_KEY",
  "SMOO_RESTAURANT_ID"
)

$values = @{}
foreach ($line in Get-Content $CredentialsPath) {
  foreach ($key in $requiredKeys) {
    if ($line.StartsWith("$key=")) {
      $values[$key] = $line.Substring($key.Length + 1)
    }
  }
}

foreach ($key in $requiredKeys) {
  if (-not $values.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($values[$key])) {
    throw "Falta $key en $CredentialsPath"
  }
}

$dartDefines = @()
foreach ($key in $requiredKeys) {
  $dartDefines += "--dart-define=$key=$($values[$key])"
}

flutter build apk --release @dartDefines
if ($LASTEXITCODE -ne 0) {
  throw "flutter build apk --release fallo. No se genero APK release valido."
}

New-Item -ItemType Directory -Force -Path "release" | Out-Null
$apkPath = Join-Path "release" $OutputName
Copy-Item -Force "build/app/outputs/flutter-apk/app-release.apk" $apkPath

$pubspecVersion = (Select-String -Path "pubspec.yaml" -Pattern "^version:" |
  Select-Object -First 1).Line.Replace("version:", "").Trim()

$buildInfoPath = [System.IO.Path]::ChangeExtension($apkPath, ".buildinfo.txt")
$aapt = Get-ChildItem -Path "$env:LOCALAPPDATA\Android\Sdk\build-tools" `
  -Recurse -Filter aapt.exe -ErrorAction SilentlyContinue |
  Sort-Object FullName -Descending |
  Select-Object -First 1

$badging = ""
$internetPermission = "NO_VERIFICADO"
if ($aapt) {
  $badging = (& $aapt.FullName dump badging $apkPath |
    Select-String -Pattern "package:|application-label:" |
    ForEach-Object { $_.Line }) -join "`r`n"
  $permissions = (& $aapt.FullName dump permissions $apkPath |
    Select-String -Pattern "android.permission.INTERNET")
  $internetPermission = if ($permissions) { "PRESENTE" } else { "AUSENTE" }
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$apkEntries = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $apkPath))
try {
  $sqliteEntries = @(
    $apkEntries.Entries |
      Where-Object { $_.FullName -match "^lib/.+/libsqlite3\.so$" } |
      ForEach-Object { $_.FullName }
  )
} finally {
  $apkEntries.Dispose()
}

$sqliteNativeLibrary = if ($sqliteEntries.Count -gt 0) { "PRESENTE" } else { "AUSENTE" }
if ($sqliteNativeLibrary -ne "PRESENTE") {
  throw "APK invalido: no contiene libsqlite3.so. Drift/SQLite fallara en Android."
}

@"
SmooControl Android Release Build
GeneratedAt=$(Get-Date -Format o)
Output=$apkPath
PubspecVersion=$pubspecVersion
CredentialSource=$CredentialsPath
InjectedDartDefines=SMOO_SUPABASE_URL,SMOO_SUPABASE_PUBLISHABLE_KEY,SMOO_RESTAURANT_ID
InternetPermission=$internetPermission
SqliteNativeLibrary=$sqliteNativeLibrary
SqliteEntries=$($sqliteEntries -join ',')

CorrectCommand=powershell -ExecutionPolicy Bypass -File .\tool\build_android_release.ps1
ForbiddenCommand=flutter build apk --release

AaptBadging:
$badging
"@ | Set-Content -Path $buildInfoPath -Encoding UTF8

Write-Host "APK generado: $apkPath"
Write-Host "Build info: $buildInfoPath"
