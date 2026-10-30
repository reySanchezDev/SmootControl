#requires -Version 7.0
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Run from the repository root. Read-only checks, apart from Flutter's normal
# generated localization/build outputs.
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Push-Location $root
try {
    Write-Host '[1/5] Reglas de 300 líneas para Dart modificado'
    $paths = @(git diff --name-only 'main...HEAD' -- '*.dart')
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo obtener la lista de cambios.' }
    $overLimit = @()
    foreach ($path in $paths) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        if ($path -match '^lib/l10n/app_localizations(_[a-z]+)?\.dart$') {
            continue # Archivos generados por Flutter.
        }
        $lines = @(Get-Content -LiteralPath $path).Count
        if ($lines -gt 300) { $overLimit += "$path ($lines líneas)" }
    }
    if ($overLimit.Count -gt 0) {
        throw ("Archivos modificados con más de 300 líneas:`n" +
            ($overLimit -join "`n"))
    }

    Write-Host '[2/5] Generar localizaciones'
    flutter gen-l10n
    if ($LASTEXITCODE -ne 0) { throw 'Flutter gen-l10n falló.' }

    Write-Host '[3/5] Análisis estático'
    flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'flutter analyze falló.' }

    Write-Host '[4/5] Pruebas del sistema de diseño y navegación'
    flutter test test/core/design_system
    if ($LASTEXITCODE -ne 0) { throw 'flutter test falló.' }

    Write-Host '[5/5] Compilación del Backoffice web'
    flutter build web --release
    if ($LASTEXITCODE -ne 0) { throw 'flutter build web falló.' }

    Write-Host 'Verificaciones automatizadas completadas.'
    Write-Host 'PENDIENTE: QA manual responsive y recorridos reales por permisos.'
} finally {
    Pop-Location
}
