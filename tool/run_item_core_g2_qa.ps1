[CmdletBinding()]
param(
    [switch]$SkipFlutter,
    [string]$Image = 'postgres:16'
)

$ErrorActionPreference = 'Stop'
$container = "smoo-item-core-g2-$([guid]::NewGuid().ToString('N').Substring(0, 12))"
$database = 'item_core_g2_qa'
$password = 'item_core_g2_qa_only'
$root = Split-Path -Parent $PSScriptRoot
$started = $false

function Invoke-PsqlFile([string]$file) {
    & docker exec -w /workspace -e PGPASSWORD=$password $container psql -X -v ON_ERROR_STOP=1 `
        -U postgres -d $database -f "/workspace/$file"
    if ($LASTEXITCODE -ne 0) { throw "PostgreSQL contract failed: $file" }
}

try {
    & docker run -d --rm --name $container `
        -e POSTGRES_PASSWORD=$password -e POSTGRES_DB=$database `
        -v "${root}:/workspace:ro" $Image `
        postgres -c fsync=on -c full_page_writes=on | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not start disposable PostgreSQL 16' }
    $started = $true

    $ready = $false
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        & docker exec -e PGPASSWORD=$password $container pg_isready `
            -U postgres -d $database *> $null
        if ($LASTEXITCODE -eq 0) { $ready = $true; break }
        Start-Sleep -Seconds 1
    }
    if (-not $ready) { throw 'Disposable PostgreSQL did not become ready' }

    Invoke-PsqlFile 'supabase/tests/item_core_g2_jwt_rls_isolated.sql'
    Invoke-PsqlFile 'supabase/tests/item_core_f2_consumption_isolated.sql'

    $tempRoot = if ($env:RUNNER_TEMP) {
        $env:RUNNER_TEMP
    }
    else {
        [System.IO.Path]::GetTempPath()
    }
    $saleDdl = Join-Path $tempRoot 'item-core-g2-sale-schema.sql'
    (Get-Content (Join-Path $root 'supabase/design/ITEM_CORE_F2_SALE_SCHEMA_DRAFT.sql')) |
        Where-Object { $_ -notmatch '^BEGIN;$' -and $_ -notmatch '^ROLLBACK;$' } |
        Set-Content -Path $saleDdl -Encoding utf8
    & docker cp $saleDdl "${container}:/tmp/item-core-g2-sale-schema.sql"
    if ($LASTEXITCODE -ne 0) { throw 'Could not copy isolated sale schema' }
    & docker exec -w /workspace -e PGPASSWORD=$password $container psql -X -v ON_ERROR_STOP=1 `
        -U postgres -d $database `
        -f /workspace/supabase/tests/item_core_f2_pos_sale_fixture.sql `
        -f /tmp/item-core-g2-sale-schema.sql `
        -f /workspace/supabase/design/ITEM_CORE_F2_CONSUMPTION_DRAFT.sql `
        -f /workspace/supabase/design/ITEM_CORE_F2_INTERNAL_LEDGER_DRAFT.sql `
        -f /workspace/supabase/design/ITEM_CORE_F2_POS_SALE_RPC_DRAFT.sql `
        -f /workspace/supabase/tests/item_core_f2_pos_sale_assert.sql
    if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL sale/void contract failed' }

    if (-not $SkipFlutter) {
        Push-Location $root
        try {
            & flutter test --no-pub `
                test/features/sync/data/repositories/item_catalog_snapshot_applier_test.dart `
                test/features/sync/domain/services/sync_queue_processor_test.dart
            if ($LASTEXITCODE -ne 0) { throw 'Flutter Drift/offline contract tests failed' }
        }
        finally { Pop-Location }
    }

    Write-Host 'PASS G2 QA: JWT/RLS=1, consumption=1, sale/void=1, Drift snapshot/offline/concurrency=1'
}
finally {
    if ($started) { & docker rm -f $container *> $null }
    if ($saleDdl -and (Test-Path $saleDdl)) {
        Remove-Item -LiteralPath $saleDdl -Force
    }
}
