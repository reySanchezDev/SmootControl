param(
  [string]$CredentialsPath = "",
  [int]$Port = 8080,
  [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($Port -lt 1024 -or $Port -gt 65535) {
  throw 'El puerto de QA debe estar entre 1024 y 65535.'
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$builder = Join-Path $PSScriptRoot 'build_web_release.ps1'
$webRoot = Join-Path $repoRoot 'build\web'

$existing = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($existing) {
  throw "El puerto $Port ya está ocupado. No se detuvo ningún proceso."
}

# Always compile RELEASE; never use flutter run/debug for QA acceptance.
$buildArgs = @{ CanonicalItemsQa = $true }
if (-not [string]::IsNullOrWhiteSpace($CredentialsPath)) {
  $buildArgs.CredentialsPath = $CredentialsPath
}
& $builder @buildArgs

foreach ($asset in @('index.html', 'main.dart.js', 'sqlite3.wasm', 'drift_worker.js')) {
  $file = Join-Path $webRoot $asset
  if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
    throw "Falta el asset requerido del release: $asset."
  }
}

$server = Start-Process -FilePath python -ArgumentList @(
  '-m', 'http.server', "$Port", '--bind', '127.0.0.1'
) -WorkingDirectory $webRoot -PassThru

$url = "http://127.0.0.1:$Port/"
$healthy = $false
for ($attempt = 1; $attempt -le 20; $attempt++) {
  Start-Sleep -Milliseconds 350
  try {
    $response = Invoke-WebRequest -UseBasicParsing $url -TimeoutSec 3
    if ($response.StatusCode -eq 200) {
      $healthy = $true
      break
    }
  } catch {
    # Initial warm-up, no Docker or process modifications.
  }
}
if (-not $healthy) {
  throw "No se verificó HTTP 200 en $url. Revisar proceso $($server.Id)."
}

Write-Host "Kivo QA RELEASE: $url (PID $($server.Id))"
Write-Host 'Supabase remoto configurado desde credenciales locales privadas.'
if (-not $NoBrowser) {
  Start-Process $url
}
