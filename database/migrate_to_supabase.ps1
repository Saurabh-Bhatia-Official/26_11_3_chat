# ====================================================================
# SUPABASE POSTGRESQL MIGRATION & VERIFICATION RUNNER
# ====================================================================
param (
    [Parameter(Mandatory=$false)]
    [string]$Password = $env:DB_PASSWORD,

    [Parameter(Mandatory=$false)]
    [string]$HostName = "db.vtxwvilrvtiklqmnbenh.supabase.co",

    [Parameter(Mandatory=$false)]
    [string]$Database = "postgres",

    [Parameter(Mandatory=$false)]
    [string]$Username = "postgres",

    [Parameter(Mandatory=$false)]
    [int]$Port = 5432
)

if (-not $Password -or $Password -eq "YOUR_SUPABASE_PASSWORD" -or $Password -eq "your_supabase_password_here") {
    Write-Host ""
    Write-Host "⚠️  Please supply your Supabase database password." -ForegroundColor Yellow
    Write-Host "Usage:" -ForegroundColor White
    Write-Host "  .\database\migrate_to_supabase.ps1 -Password 'your_password'" -ForegroundColor Cyan
    Write-Host "Or configure DB_PASSWORD in .env" -ForegroundColor White
    Write-Host ""
    exit 1
}

$PsqlCandidates = @(
    "C:\Program Files\PostgreSQL\18\bin\psql.exe",
    "C:\Program Files\PostgreSQL\17\bin\psql.exe",
    "C:\Program Files\PostgreSQL\16\bin\psql.exe",
    (Get-Command psql -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
)

$PsqlPath = $PsqlCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

if (-not $PsqlPath) {
    Write-Host "❌ psql.exe was not found. Please ensure PostgreSQL client tools are installed." -ForegroundColor Red
    exit 1
}

$env:PGPASSWORD = $Password

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "🚀 Migrating & Verifying Supabase Database" -ForegroundColor Cyan
Write-Host "Host:     $HostName" -ForegroundColor White
Write-Host "Port:     $Port" -ForegroundColor White
Write-Host "Database: $Database" -ForegroundColor White
Write-Host "User:     $Username" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Test Connectivity
Write-Host ">>> [1/3] Testing Connection..." -ForegroundColor Yellow
$testOutput = & $PsqlPath -h $HostName -p $Port -U $Username -d $Database -c "SELECT version();" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Connection failed: $testOutput" -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host "✅ Successfully authenticated to Supabase PostgreSQL!" -ForegroundColor Green

# 2. Apply Schema & Relationships
Write-Host ">>> [2/3] Applying Schema (schema.sql)..." -ForegroundColor Yellow
$schemaPath = Join-Path $PSScriptRoot "schema.sql"
& $PsqlPath -h $HostName -p $Port -U $Username -d $Database -f $schemaPath
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to execute schema.sql on Supabase." -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host "✅ Schema, extensions, tables, foreign keys, and indexes applied!" -ForegroundColor Green

# 3. Verify Tables & Schemas
Write-Host ">>> [3/3] Verifying Tables..." -ForegroundColor Yellow
$verifyQuery = "SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name;"
& $PsqlPath -h $HostName -p $Port -U $Username -d $Database -c $verifyQuery

Write-Host ""
Write-Host "🎉 Supabase migration and verification completed successfully!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
