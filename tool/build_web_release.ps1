param(
  [string]$CredentialsPath = "",
  [switch]$CanonicalItemsQa,
  [switch]$LocalSupabaseQa
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$credentialsRelativePath = Join-Path 'Requerimiento' 'CredencialesSupabase.md'
$requiredKeys = @(
  'SMOO_SUPABASE_URL',
  'SMOO_SUPABASE_PUBLISHABLE_KEY',
  'SMOO_RESTAURANT_ID'
)

# The file is deliberately local and must never be copied to another worktree
# or committed. An explicit path or environment variable overrides discovery.
$candidates = @()
if (-not [string]::IsNullOrWhiteSpace($CredentialsPath)) {
  $candidates += $CredentialsPath
} elseif (-not [string]::IsNullOrWhiteSpace($env:SMOO_CREDENTIALS_PATH)) {
  $candidates += $env:SMOO_CREDENTIALS_PATH
} else {
  $candidates += (Join-Path $repoRoot $credentialsRelativePath)
  $parent = Split-Path $repoRoot -Parent
  $candidates += (Join-Path (Join-Path $parent 'SmooControl-backoffice-stabilization-integration') $credentialsRelativePath)
}

$credentialsFile = $null
foreach ($candidate in $candidates) {
  if (Test-Path -LiteralPath $candidate -PathType Leaf) {
    $credentialsFile = (Resolve-Path -LiteralPath $candidate).Path
    break
  }
}

if ($null -eq $credentialsFile) {
  throw @'
No se genero el Web release: falta el archivo local de configuracion Supabase.
Usa -CredentialsPath "RUTA_LOCAL" o SMOO_CREDENTIALS_PATH.
El build se detuvo ANTES de flutter clean; no copies credenciales al repositorio.
'@
}

$values = @{}
foreach ($line in Get-Content -LiteralPath $credentialsFile) {
  foreach ($key in $requiredKeys) {
    if ($line.TrimStart().StartsWith("$key=")) {
      $values[$key] = $line.TrimStart().Substring($key.Length + 1).Trim()
    }
  }
}

$missing = @($requiredKeys | Where-Object {
  -not $values.ContainsKey($_) -or
  [string]::IsNullOrWhiteSpace($values[$_])
})
if ($missing.Count -gt 0) {
  throw "No se genero el Web release: faltan las variables obligatorias $($missing -join ', '). No se imprimen valores."
}

if ($LocalSupabaseQa -and -not $CanonicalItemsQa) {
  throw 'LocalSupabaseQa requiere CanonicalItemsQa.'
}
if ($LocalSupabaseQa) {
  # Local Docker is allowed only on loopback; never permit cleartext remote hosts.
  if ($values['SMOO_SUPABASE_URL'] -notmatch '^http://(127[.]0[.]0[.]1|localhost):54321/?$') {
    throw 'QA Docker requiere Supabase HTTP local en 127.0.0.1:54321 o localhost:54321.'
  }
} elseif ($values['SMOO_SUPABASE_URL'] -notmatch '^https://[^/]+') {
  throw 'No se genero el Web release: SMOO_SUPABASE_URL no es una URL https valida.'
}

$dartDefines = @($requiredKeys | ForEach-Object {
  "--dart-define=$_=$($values[$_])"
})

if ($CanonicalItemsQa) {
  $dartDefines += '--dart-define=SMOO_ITEM_CORE_V2_QA=true'
  $dartDefines += '--dart-define=SMOO_APP_MODE=backoffice'
  Write-Host 'QA RELEASE: Backoffice autenticado (sin inicializacion POS).'
  if ($LocalSupabaseQa) {
    Write-Host 'QA RELEASE: Supabase del Docker local, sin tocar el remoto.'
  }
}

Push-Location $repoRoot
try {
  flutter clean
  if ($LASTEXITCODE -ne 0) { throw 'flutter clean fallo.' }
  flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub get fallo.' }
  dart compile js -O2 -o web\drift_worker.js web\drift_worker.dart
  if ($LASTEXITCODE -ne 0) { throw 'Compilacion del worker Drift fallo.' }
  flutter build web --release --no-wasm-dry-run --no-web-resources-cdn --pwa-strategy=none @dartDefines
  if ($LASTEXITCODE -ne 0) { throw 'flutter build web fallo.' }

  Copy-Item web\sqlite3.wasm build\web\sqlite3.wasm -Force
  Copy-Item web\drift_worker.js build\web\drift_worker.js -Force
  Write-Host 'Build Web release listo: configuracion Supabase validada y assets Drift copiados (sin mostrar valores).'
} finally {
  Pop-Location
}
