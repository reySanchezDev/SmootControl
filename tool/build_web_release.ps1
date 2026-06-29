param(
  [string]$CredentialsPath = "Requerimiento/CredencialesSupabase.md"
)

$ErrorActionPreference = 'Stop'

$requiredKeys = @(
  "SMOO_SUPABASE_URL",
  "SMOO_SUPABASE_PUBLISHABLE_KEY",
  "SMOO_RESTAURANT_ID",
  "SMOO_SUPABASE_AUTH_EMAIL",
  "SMOO_SUPABASE_AUTH_PASSWORD"
)

$dartDefines = @()
if (Test-Path $CredentialsPath) {
  $values = @{}
  foreach ($line in Get-Content $CredentialsPath) {
    foreach ($key in $requiredKeys) {
      if ($line.StartsWith("$key=")) {
        $values[$key] = $line.Substring($key.Length + 1)
      }
    }
  }

  foreach ($key in $requiredKeys) {
    if ($values.ContainsKey($key) -and
        -not [string]::IsNullOrWhiteSpace($values[$key])) {
      $dartDefines += "--dart-define=$key=$($values[$key])"
    }
  }
}

flutter clean
flutter pub get
dart compile js -O2 -o web\drift_worker.js web\drift_worker.dart
flutter build web --release --no-wasm-dry-run --no-web-resources-cdn --pwa-strategy=none @dartDefines

Copy-Item web\sqlite3.wasm build\web\sqlite3.wasm -Force
Copy-Item web\drift_worker.js build\web\drift_worker.js -Force

Write-Host 'Build Web release listo con assets Drift copiados.'
