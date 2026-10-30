#requires -Version 7.0
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Run from the repository root. Read-only checks, apart from Flutter's normal
# generated localization/build outputs.
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Push-Location $root
try {
    Write-Host '[1/5] Reglas de 300 líneas para Dart modificado'
    # A pull-request checkout may not create a local main branch.
    git rev-parse --verify 'refs/remotes/origin/main' *> $null
    $base = if ($LASTEXITCODE -eq 0) {
        'origin/main'
    } else {
        git rev-parse --verify 'refs/heads/main' *> $null
        if ($LASTEXITCODE -ne 0) {
            throw 'No se encontró origin/main ni main para comparar.'
        }
        'main'
    }
    $paths = @(git diff --name-only "$base...HEAD" -- '*.dart')
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
    # The legacy base contains four known lint findings outside this UX change.
    # They are explicitly tracked, not silently ignored. Any new warning/info
    # (including ones in changed files) fails this gate; analyzer errors always fail.
    $baseline = @{
        'lib/features/auth/data/services/remote_bootstrap_auth_service.dart|unawaited_return_in_try_block' = $true
        'lib/features/expenses/presentation/widgets/expenses_overview_list.dart|prefer_if_elements_to_conditional_expressions' = $true
        'lib/features/sales/presentation/pages/sales_page.dart|unnecessary_unawaited' = $true
        'lib/features/system/presentation/pages/pilot_operation_reset_actions_part.dart|unawaited_return_in_try_block' = $true
    }
    $analysisOutput = @(flutter analyze --no-fatal-infos --no-fatal-warnings 2>&1)
    $analysisOutput | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) { throw 'flutter analyze encontró errores.' }
    $newFindings = @()
    foreach ($line in $analysisOutput) {
        if ([string]$line -match '(?:info|warning)\s+•.*•\s+([^:\s]+\.dart):\d+:\d+\s+•\s+([a-z_]+)') {
            $key = "$($Matches[1])|$($Matches[2])"
            if (-not $baseline.ContainsKey($key)) {
                $newFindings += [string]$line
            }
        }
    }
    if ($newFindings.Count -gt 0) {
        throw ("Nuevos avisos de análisis (sin excepción):`n" +
            ($newFindings -join "`n"))
    }
    if ($analysisOutput -match '(?:info|warning)\s+•') {
        Write-Warning 'Existen avisos heredados registrados; cero avisos globales aún es una deuda de calidad.'
    }

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
