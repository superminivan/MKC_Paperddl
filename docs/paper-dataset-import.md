# Paper Dataset Import Guide

`paperddl` supports an optional paper dataset stored in MySQL table `papers`.
The `/paper-cool` frontend pages call backend APIs that read from this table.

## Input File

Default dataset file:

```text
pre4data/merged_all_results.json
```

The JSON must be a top-level array. Each item is one paper record and should contain fields such as `paper_id`, `conference`, `year`, `subjects`, `title`, `authors`, `abstract`, `pdf_url`, `keywords`, `doi`, and `source_file`.

## One-Command Import (Windows PowerShell)

Run from the `paperddl/` folder:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/import-papers-dataset.ps1
```

Use another JSON file:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/import-papers-dataset.ps1 -JsonPath "D:\data\merged_all_results.json"
```

Append instead of refreshing the table:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/import-papers-dataset.ps1 -Append
```

Skip migrations when the schema is already ready:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/import-papers-dataset.ps1 -SkipMigrations
```

## What The Script Does

1. Checks that `server/.env` and the dataset JSON exist.
2. Installs npm dependencies if `node_modules` is missing.
3. Applies migrations:
   - `server/migrations/001_auth.sql`
   - `server/migrations/002_favorites.sql`
   - `server/migrations/003_papers.sql`
4. Runs `npm run papers:import`.
5. Prints verification totals and top venues.

## Manual Import

Install dependencies:

```powershell
npm install
npm --prefix server install
npm --prefix web install
```

Apply migrations with MySQL CLI:

```powershell
Get-Content server/migrations/001_auth.sql | mysql -u paperddl -p paperddl
Get-Content server/migrations/002_favorites.sql | mysql -u paperddl -p paperddl
Get-Content server/migrations/003_papers.sql | mysql -u paperddl -p paperddl
```

Import default JSON:

```powershell
npm run papers:import
```

Import a custom JSON:

```powershell
npm --prefix server run papers:import -- "D:\data\merged_all_results.json"
```

Append instead of truncate-and-refresh:

```powershell
npm --prefix server run papers:import -- "D:\data\merged_all_results.json" --append
```

## Verification SQL

```sql
SELECT COUNT(*) AS total,
       COUNT(DISTINCT conference) AS venues,
       MIN(year) AS min_year,
       MAX(year) AS max_year
FROM papers;

SELECT conference, COUNT(*) AS count
FROM papers
GROUP BY conference
ORDER BY count DESC
LIMIT 10;
```

## Notes

- Default import truncates `papers` before inserting records.
- Array fields such as `subjects`, `authors`, `keywords`, and `editor` are stored as JSON.
- Search helper text columns such as `authors_text` and `keywords_text` are populated during import.
- `track` is derived from `subjects[0]`, for example `CVPR.2025 - Poster` becomes `Poster`.
- Backend paper APIs:
  - `GET /api/papers`
  - `GET /api/papers/venues`
  - `GET /api/papers/tracks?conference=CVPR`
