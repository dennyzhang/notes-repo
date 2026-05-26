# P-010: Source Migration Audits Downstream Schemas

**Statement:** When a cron's data source changes (new field, renamed enum, different format), audit downstream artifact schemas — filenames, INDEX columns, README enums, lint regexes — not just the query call. Source migrations cascade silently into downstream consumers.

**Discovered:** 2026-05-17 thread `Uc-pVBEXNQ8` — priority taxonomy migration from P0-P4 to critical/high/medium/low/unknown (OneDetection urgency) required renaming 1 archive + updating 3 monitor crons + INDEX format + README enums.

**Why it matters:** Source migrations look like "1 field change" but actually invalidate downstream regexes, file glob patterns, and README expectations. Missing one downstream consumer = months of subtle data corruption.

**Applies to:** any agent maintaining derived artifacts from upstream sources.

**Current applications:**
- Priority taxonomy migration (P0-P4 → criticality enum) — touched 5 files + setup-cron-jobs to re-arm
- AGG sub-alert expansion (R22) — required CL-018 re-classification + archive backfill + 3 monitor cron updates
- failure-patterns.md INDEX column rename "Cluster" → "Error pattern" across 3 archive subdirs

**Anti-patterns it prevents:**
- Renaming a field in 1 cron, leaving downstream INDEX/README using old name
- Adding new enum value but lint regex still rejects it (silent suppression)
- Schema change without `regen-archive-indexes.sh` invocation

**Related principles:** P-002 (shipping requires execution = test downstream consumers), P-011 (spec vs lint)
