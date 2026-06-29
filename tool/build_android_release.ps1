param(
  [string]$OutputName = "SmooControl-produccion.apk",
  [string]$CredentialsPath = "Requerimiento/CredencialesSupabase.md"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $CredentialsPath)) {
  throw "No se encontro $CredentialsPath"
}

$requiredKeys = @(
  "SMOO_SUPABASE_URL",
  "SMOO_SUPABASE_PUBLISHABLE_KEY",
  "SMOO_RESTAURANT_ID",
  "SMOO_SUPABASE_AUTH_EMAIL",
  "SMOO_SUPABASE_AUTH_PASSWORD"
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

New-Item -ItemType Directory -Force -Path "release" | Out-Null
Copy-Item -Force "build/app/outputs/flutter-apk/app-release.apk" "release/$OutputName"

Write-Host "APK generado: release/$OutputName"
