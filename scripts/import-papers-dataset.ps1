<#
.SYNOPSIS
Batch import paper dataset JSON into the MySQL papers table.

.DESCRIPTION
Recommended entry point for initializing or refreshing the paper dataset
used by the backend paper APIs and the /paper-cool frontend pages.

Steps:
1. Validate that server/.env and the input JSON file exist.
2. Install dependencies when node_modules is missing.
3. Apply MySQL migrations:
   - server/migrations/001_auth.sql
   - server/migrations/002_favorites.sql
   - server/migrations/003_papers.sql
4. Import the paper JSON with server/src/import-papers.js.
5. Verify imported row counts and venue statistics.

The import script reads MySQL connection settings from server/.env:
MYSQL_HOST, MYSQL_PORT, MYSQL_DATABASE, MYSQL_USER, MYSQL_PASSWORD.

By default, papers are refreshed by truncating the papers table first.
Use -Append to keep existing rows and append new data.

.PARAMETER JsonPath
Path to the merged paper JSON file. Defaults to pre4data/merged_all_results.json.

.PARAMETER Append
Append records instead of truncating the papers table first.

.PARAMETER SkipMigrations
Skip applying SQL migrations. Use this when the schema is already initialized.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File scripts/import-papers-dataset.ps1

.EXAMPLE
powershell -ExecutionPolicy Bypass -File scripts/import-papers-dataset.ps1 -JsonPath "D:\data\merged_all_results.json"

.EXAMPLE
powershell -ExecutionPolicy Bypass -File scripts/import-papers-dataset.ps1 -Append
#>

param(
  [string]$JsonPath = "pre4data/merged_all_results.json",
  [switch]$Append,
  [switch]$SkipMigrations
)

$ErrorActionPreference = "Stop"

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Resolve-RepoPath {
  param([string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Path))
}

$repoRoot = [System.IO.Path]::GetFullPath((Get-Location))
$serverEnv = Join-Path $repoRoot "server/.env"
$jsonFullPath = Resolve-RepoPath $JsonPath

Write-Step "Validating project files"
if (!(Test-Path (Join-Path $repoRoot "package.json"))) {
  throw "Please run this script from the paperddl repository root."
}

if (!(Test-Path $serverEnv)) {
  throw "Missing server/.env. Copy server/.env.example to server/.env and configure MySQL first."
}

if (!(Test-Path $jsonFullPath)) {
  throw "JSON file not found: $jsonFullPath"
}

Write-Host "Repository: $repoRoot"
Write-Host "Dataset JSON: $jsonFullPath"

Write-Step "Ensuring npm dependencies"
if (!(Test-Path (Join-Path $repoRoot "node_modules"))) {
  npm install
}
if (!(Test-Path (Join-Path $repoRoot "server/node_modules"))) {
  npm --prefix server install
}

if (!$SkipMigrations) {
  Write-Step "Applying database migrations"
  $migrationJs = @"
import fs from 'node:fs/promises';
import './server/src/env.js';
import { pool } from './server/src/db.js';

const migrations = [
  'server/migrations/001_auth.sql',
  'server/migrations/002_favorites.sql',
  'server/migrations/003_papers.sql'
];

for (const file of migrations) {
  const sql = await fs.readFile(file, 'utf8');
  await pool.query(sql);

  // Avoid template-string interpolation issues in shells.
  console.log('[migration] applied ' + file);
}

await pool.end();
"@

  node --input-type=module -e $migrationJs
}

Write-Step "Importing paper dataset"
$importArgs = @("run", "papers:import", "--", $jsonFullPath)
if ($Append) {
  $importArgs += "--append"
}

npm @importArgs

Write-Step "Verifying imported data"
$verifyJs = @"
import './server/src/env.js';
import { execute, pool } from './server/src/db.js';

const totals = await execute('\
  SELECT\
    COUNT(*) AS total,\
    COUNT(DISTINCT conference) AS venues,\
    MIN(year) AS min_year,\
    MAX(year) AS max_year\
  FROM papers\
');

const topVenues = await execute('\
  SELECT conference, COUNT(*) AS count\
  FROM papers\
  GROUP BY conference\
  ORDER BY count DESC\
  LIMIT 10\
');

console.log('[verify] totals:', totals[0]);
console.log('[verify] top venues:');
for (const row of topVenues) {
  console.log('  ' + row.conference + ': ' + row.count);
}

await pool.end();
"@

node --input-type=module -e $verifyJs

Write-Step "Done"
Write-Host "Backend paper APIs now read from the MySQL papers table:"
Write-Host "  GET /api/papers"
Write-Host "  GET /api/papers/venues"
Write-Host "  GET /api/papers/tracks?conference=CVPR"
