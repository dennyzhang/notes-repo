# `mrs-ot-agent-context/` — Directory Taxonomy

_OT bot's learning outputs, incident archives, cron-curated health surfaces, and
operator-curated context. Sibling to `mrs-ot-agent-src/` (the bot's CODE + cron
runtime state) — this directory is what the bot LEARNS and what humans TEACH it._

## Data flow at a glance

```
[Real-time triage]   ot-{sev,alert,post}-monitor (15min-1hr)  →  GChat triage
                                  ↓ on resolution
[Per-incident]       ot-daily-learning-mitigated-{sevs,posts,alerts} (nightly)
                     → incidents/resolved-{sevs,posts,alerts}/<YYYY-MM>/<file>.md
                                  ↓ ot-knowledge-distillation (weekday)
[Cross-incident]     auto-learnings/digests/2026-W<NN>.md
                                  ↓ operator promotion
[Cluster registry]   auto-learnings/patterns/failure-patterns.md  ← TL surface
                                  ↑ cross-link
[Archive indexes]    incidents/resolved-{sevs,posts,alerts}/INDEX.md

[Fleet health]       ot-fleet-health (daily) → state/fleet-health-history/<YYYY-MM>/runs.jsonl
                     suppression registry    → state/known-issues/registry.json
[Systemic synthesis] ot-knowledge-curation (nightly) → systemic-gaps/<YYYY-MM>.md
[Gdoc/skill sync]    ot-ingest-gdocs (daily) → references/{gdocs,skills}/
```

See [`solution-design.md`](solution-design.md) for flywheel goal, problems, metrics, and improvement proposals.

## Quick navigation

| Looking for... | Go here |
|---|---|
| **Cluster registry** (TL surface) | `auto-learnings/patterns/failure-patterns.md` |
| **Knowledge graph** (S→M→R→P→D traversal) | `auto-learnings/patterns/INDEX.md` |
| **Archive indexes** (cluster→archive mapping) | `incidents/resolved-{sevs,posts,alerts}/INDEX.md` |
| 4-week trend synthesis | `auto-learnings/digests/TREND-4-week-*.md` |
| Per-week digests | `auto-learnings/digests/2026-W<NN>.md` |
| Mega weekly rollups | `auto-learnings/mega/2026-W<NN>.md` |
| Prod-health observability (metrics/queries/SLOs) | `metrics/INDEX.md` |
| Systemic-gap monthly reports | `systemic-gaps/<YYYY-MM>.md` |
| Fleet-health run history | `state/fleet-health-history/<YYYY-MM>/runs.jsonl` |
| Fleet-health suppression registry | `state/known-issues/registry.json` (edit via `../mrs-ot-agent-src/tools/add-known-issue.sh`) |
| OT prod workload inventory | `auto-learnings/inventory/workloads.md` |
| SJD coverage gap catalog | `auto-learnings/patterns/sjd-coverage-map.md` |
| Auto-fix work (current) | open `[OT auto-fix]` tasks → `--draft` diffs (via `ot-autofix-diff-drafter`); `auto-fixes/*.md` is legacy (≤2026-05) |
| Daily learning ledger | `auto-learnings/daily-ledger.md` |
| Candidate-learning ledger (<3 samples) | `auto-learnings/learnings-ledger.md` |
| Chronic-noisy trend tracking | `auto-learnings/noisy-trends.md` |
| OT-specific triage rules (R1-R22) | `../mrs-ot-agent-src/human-input/triage-discipline.md` (**ground truth**; the old `human-input-domain/triage-discipline.md` stub was removed 2026-06-11) |
| Generic triage methodology (R1-R13) | `~/notes/users/dennyzhang/cheatsheets/oncall/triage-methodology.md` (**ground truth**; `human-input-generic/triage-methodology.md` is a deprecated stub) |
| Known OT failure patterns (P-rows) | `human-input-domain/known-patterns.md` |
| SEV 1/2/3 criteria (level assignment) | `human-input-domain/sev-criteria.md` (synced from gdoc) |
| Team routing / ownership | `human-input-domain/ownership.md` |
| Agent design principles (P-001→) | `human-input-generic/principles/INDEX.md` |
| Synced OT gdocs (auto-written) | `references/gdocs/` |
| Mirrored skill sources | `references/skills/` |
| Reinstall runbook | `references/ot-bot-reinstall-runbook.md` |
| Per-incident SEV / post / alert archives | `incidents/resolved-{sevs,posts,alerts}/<YYYY-MM>/` |
| Per-conversation thread summaries | `bot-debugging-threads/<YYYY-MM>/` |
| **War stories** (deep incident narratives) | `war-stories/INDEX.md` |
| Daily orphan fbpkg dumps | `incidents/fbpkg-audits/<YYYY-MM-DD>.json` |

```
mrs-ot-agent-context/
├── README.md                              ← This file
├── solution-design.md                     ← flywheel goal, problems, metrics, proposals, principles
├── auto-learnings/                        (see auto-learnings/INDEX.md)
│   ├── daily-ledger.md                    (append-only operational lessons)
│   ├── learnings-ledger.md                (candidate learnings below the ≥3-sample bar)
│   ├── noisy-trends.md                    (chronic-noisy tracking: alerts + SEVs + posts)
│   ├── patterns/                          ← cluster registry + knowledge graph (S→M→R→P→D)
│   │   ├── failure-patterns.md            ← stable [CL-NNN] cluster registry (TL surface)
│   │   ├── {symptoms,failure-modes,root-causes,mitigations,systemic-causes}.md
│   │   ├── known-issues-lifecycle.md  sjd-coverage-map.md
│   │   └── INDEX.md                       ← operator entry point (S→M→R→P→D traversal)
│   ├── digests/                           ← weekly + monthly cross-incident synthesis
│   ├── mega/                              ← mega weekly rollups (2026-W<NN>.md)
│   ├── inventory/                         ← workload inventory, heatmap, taxonomy, trending
│   ├── deep-dives/                        (incident-derived triage examples + deep dives)
│   └── references/                        (point-in-time reference snapshots, e.g. SLOs)
├── auto-fixes/<YYYY-MM>/                   (LEGACY markdown patches ≤2026-05; live flow = [OT auto-fix] tasks → draft diffs. See auto-fixes/INDEX.md)
├── human-input-domain/                    (OT-specific operator knowledge)
│   ├── known-patterns.md                  (P-rows: known OT failure patterns)
│   ├── triage-discipline.md               (DEPRECATED stub → mrs-ot-agent-src/human-input/triage-discipline.md)
│   ├── ownership.md                       (team routing)
│   └── howto.md                           (operator how-to notes)
├── human-input-generic/                   (reusable across projects)
│   ├── triage-methodology.md              (DEPRECATED stub → cheatsheets/oncall/triage-methodology.md)
│   ├── principles/                        (P-001→ agent design principles + INDEX)
│   └── report-templates/                  (crisp-report-style.md)
├── incidents/
│   ├── resolved-sevs/   <YYYY-MM>/        + INDEX.md + noisy-models.md
│   ├── resolved-posts/  <YYYY-MM>/        + INDEX.md
│   ├── resolved-alerts/ <YYYY-MM>/        + INDEX.md
│   ├── open.md                            (active incidents the team is working on)
│   └── fbpkg-audits/<YYYY-MM-DD>.json
├── metrics/                               (prod-health observability reference; see metrics/INDEX.md)
│   └── {user-journeys,slo-recovery-metrics,queries,detection-patterns}.md
├── systemic-gaps/<YYYY-MM>.md             (ot-knowledge-curation monthly synthesis)
├── references/                            (cron-synced external context)
│   ├── gdocs/                             (ot-ingest-gdocs mirror — AUTO-WRITTEN)
│   ├── skills/                            (skill-source mirror + skill-sources.json)
│   └── ot-bot-reinstall-runbook.md
├── bot-debugging-threads/<YYYY-MM>/       (per-thread conversation summaries)
├── war-stories/                           (deep incident narratives + INDEX.md)
└── state/                                 ← operational bookkeeping (not learnings; AUTO-WRITTEN)
    ├── fleet-health-history/<YYYY-MM>/runs.jsonl   (ot-fleet-health daily run log)
    └── known-issues/registry.json         (fleet-health suppression registry; TTL-expiring)
```

## Taxonomy

| Layer | Directories | Purpose |
|---|---|---|
| **Solution design** (operator + bot) | `solution-design.md` | Flywheel goal, guiding metrics, problem inventory, design principles, improvement proposals |
| **Distilled patterns** (bot-generated) | `auto-learnings/` | Cross-incident synthesis, cluster registry, knowledge graph, workload inventory, operational lessons |
| **Raw archives** (bot-generated) | `incidents/resolved-*/`, `incidents/fbpkg-audits/` | One-file-per-incident; durable record of WHAT happened |
| **Systemic synthesis** (cron-generated) | `systemic-gaps/` | Monthly recurring-root-cause reports (ot-knowledge-curation) |
| **Observability reference** (operator + bot) | `metrics/` | User journeys, key metrics + thresholds, canonical queries, detection patterns |
| **Operator-curated priors** (human-written) | `human-input-domain/` | OT-specific: ownership, known patterns, triage rules R11-R18, how-to |
| **Generic methodology** (human-written) | `human-input-generic/` | Reusable: triage methodology R1-R10, agent principles, report templates |
| **Synced external context** (cron-generated) | `references/` | Mirrored gdocs + skill sources + runbooks |
| **Per-conversation rollups** | `bot-debugging-threads/` | Per-thread distillations from operator-bot debugging sessions |
| **Bot-proposed fixes** | `auto-fixes/` (legacy) | Markdown fix patches ≤2026-05. Superseded by `[OT auto-fix]` tasks → `--draft` diffs (`ot-autofix-diff-drafter`); land-rate is the metric, not file count |
| **War stories** | `war-stories/` | Deep narratives of significant incidents — teaching artifacts for new oncall |
| **Operational state** (cron-written) | `state/` | Bookkeeping the daemon reads to run — NOT learnings: `fleet-health-history/` run log + `known-issues/` suppression registry. Notes-only, never mirrored to fbcode. |

## Operational state (`state/`)

`state/` groups the cron-written **operational bookkeeping** the daemon reads to
run — `fleet-health-history/` (daily run-log jsonl) and `known-issues/`
(TTL-expiring suppression registry). This is NOT learnings or teachings, but it
lives in context because it is notes-versioned and never mirrored to fbcode.
Writers: `ot-fleet-health` + `tools/{persist-fleet-history,render-fleet-digest,add-known-issue}`.

Two stale duplicate copies were removed during the 2026-06-10 restructure
(zero data loss — each was a subset of its live source):
- `state/ot-debug-quality-state.json` — live copy is `../mrs-ot-agent-src/state/`
  (what `ot-debug-quality-weekly` writes).
- `myclaw-memory/<space-id>/` — was an 11-of-53 stale snapshot of the daemon's
  live memory at `~/.myclaw-ot-bot/spaces/<space-id>/memory/`, which is the only
  copy the bot reads/writes.

## What's NOT here

- **Cron prompts** — `../mrs-ot-agent-src/team_bot/cron-jobs/`
- **Cron runtime state** — `../mrs-ot-agent-src/state/` (canonical home; see "Runtime state" above)
- **Bot identity files** — `../mrs-ot-agent-src/agent_identity/`
- **Bot CODE** (capabilities, src/) — `fbcode/pe_mrs_ml/mrs_ot_agent/`
- **Concept glossary** — `../mrs-ot-agent-src/deep-dives/concepts.md`
- **P-rows canonical** — `../mrs-ot-agent-src/known_patterns.md` (`human-input-domain/known-patterns.md` is the context copy)

## Conventions

- **Append-only IDs:** `auto-learnings/patterns/failure-patterns.md` uses CL-NNN IDs. Never renumber, never reuse.
- **Monthly archive rotation:** all per-incident + fleet-health archives live in `<dir>/<YYYY-MM>/`. No deletion; sl history preserves everything.
- **AUTO-WRITTEN dirs** (`references/gdocs/`, `references/skills/`, `state/fleet-health-history/`): never hand-edit — a cron overwrites them. Fix the source instead.
- **Push target = `master`.** Never `--to remote/default`. See `~/notes/users/dennyzhang/cheatsheets/notes-repo-operations.md`.
