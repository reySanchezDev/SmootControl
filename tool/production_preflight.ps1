param(
  [string]$CredentialsPath = "Requerimiento/CredencialesSupabase.md",
  [switch]$SkipTests
)

$ErrorActionPreference = "Stop"

function Write-Section {
  param([string]$Title)
  Write-Host ""
  Write-Host "== $Title =="
}

Write-Section "Git status"
git status --short

Write-Section "Version"
$pubspec = Get-Content "pubspec.yaml"
$versionLine = $pubspec | Where-Object { $_ -match "^version:\s+" } | Select-Object -First 1
if (-not $versionLine) {
  throw "No se encontro version en pubspec.yaml"
}
$version = ($versionLine -replace "^version:\s+", "").Trim()
Write-Host "pubspec version: $version"
if ($version -notmatch "^\d+\.\d+\.\d+\+\d+$") {
  throw "La version debe tener formato versionName+versionCode, por ejemplo 0.1.15+20"
}

Write-Section "Credenciales Supabase"
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
  Write-Host "${key}: OK"
}

Write-Section "Flutter analyze"
flutter analyze

if (-not $SkipTests) {
  Write-Section "Flutter test"
  flutter test
} else {
  Write-Host ""
  Write-Host "== Flutter test =="
  Write-Host "Omitido por parametro -SkipTests"
}

Write-Section "Preflight completo"
Write-Host "Analisis finalizado. Revisa git status y confirma versionCode antes de construir APK."
