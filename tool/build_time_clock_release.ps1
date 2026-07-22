param(
  [string]$OutputName = "SmooControl-marcador.apk",
  [string]$CredentialsPath = "Requerimiento/CredencialesSupabase.md"
)

$ErrorActionPreference = "Stop"

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

$dartDefines = @("--dart-define=SMOO_APP_MODE=time_clock")
foreach ($key in $requiredKeys) {
  $dartDefines += "--dart-define=$key=$($values[$key])"
}

flutter build apk --release --flavor timeClock @dartDefines
if ($LASTEXITCODE -ne 0) {
  throw "flutter build apk --release --flavor timeClock fallo."
}

New-Item -ItemType Directory -Force -Path "release" | Out-Null
$apkPath = Join-Path "release" $OutputName
Copy-Item -Force "build/app/outputs/flutter-apk/app-timeClock-release.apk" $apkPath

$pubspecVersion = (Select-String -Path "pubspec.yaml" -Pattern "^version:" |
  Select-Object -First 1).Line.Replace("version:", "").Trim()

$buildInfoPath = [System.IO.Path]::ChangeExtension($apkPath, ".buildinfo.txt")
$aapt = Get-ChildItem -Path "$env:LOCALAPPDATA\Android\Sdk\build-tools" `
  -Recurse -Filter aapt.exe -ErrorAction SilentlyContinue |
  Sort-Object FullName -Descending |
  Select-Object -First 1

$badging = ""
if ($aapt) {
  $badging = (& $aapt.FullName dump badging $apkPath |
    Select-String -Pattern "package:|application-label:" |
    ForEach-Object { $_.Line }) -join "`r`n"
}

@"
SmooControl Time Clock Android Release Build
GeneratedAt=$(Get-Date -Format o)
Output=$apkPath
PubspecVersion=$pubspecVersion
CredentialSource=$CredentialsPath
InjectedDartDefines=SMOO_APP_MODE,SMOO_SUPABASE_URL,SMOO_SUPABASE_PUBLISHABLE_KEY,SMOO_RESTAURANT_ID
CorrectCommand=powershell -ExecutionPolicy Bypass -File .\tool\build_time_clock_release.ps1

AaptBadging:
$badging
"@ | Set-Content -Path $buildInfoPath -Encoding UTF8

Write-Host "APK marcador generado: $apkPath"
Write-Host "Build info: $buildInfoPath"
