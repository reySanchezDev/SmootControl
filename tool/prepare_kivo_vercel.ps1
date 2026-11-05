param(
  [string]$CredentialsPath = "",
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$distribution = Join-Path $root 'build/web'
$stage = Join-Path $root 'release/kivo-vercel'
$public = Join-Path $stage 'public'

Push-Location $root
try {
  if (-not $SkipBuild) {
    & (Join-Path $PSScriptRoot 'build_web_release.ps1') -CredentialsPath $CredentialsPath
    if ($LASTEXITCODE -ne 0) { throw 'Fallo el build Web oficial.' }
  }

  foreach ($required in @('index.html','flutter_bootstrap.js','main.dart.js','drift_worker.js','sqlite3.wasm')) {
    if (-not (Test-Path -LiteralPath (Join-Path $distribution $required) -PathType Leaf)) {
      throw "No se puede preparar Vercel: falta $required. Ejecuta el build Web oficial."
    }
  }

  New-Item -ItemType Directory -Force -Path $stage | Out-Null
  if (Test-Path -LiteralPath $public) {
    Remove-Item -LiteralPath $public -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path $public | Out-Null
  Copy-Item -Path (Join-Path $distribution '*') -Destination $public -Recurse -Force

  # Deploy only the precompiled static site. Vercel must not rebuild Flutter.
  $config = @{
    '$schema' = 'https://openapi.vercel.sh/vercel.json'
    framework = $null
    buildCommand = $null
    outputDirectory = 'public'
    rewrites = @(
      @{ source = '/:path*'; destination = '/index.html' }
    )
  }
  $json = $config | ConvertTo-Json -Depth 8
  [System.IO.File]::WriteAllText(
    (Join-Path $stage 'vercel.json'),
    $json,
    [System.Text.UTF8Encoding]::new($false)
  )

  Write-Host "Kivo Web preparado en $stage"
  Write-Host 'No se ha desplegado en Vercel.'
  Write-Host ('Vincular proyecto nuevo: vercel link --cwd "{0}"' -f $stage)
  Write-Host ('Publicar sitio validado: vercel deploy --prod --cwd "{0}"' -f $stage)
} finally {
  Pop-Location
}
