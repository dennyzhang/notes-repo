# `mrs-ot-agent-context/` — Directory Taxonomy

_OT bot's learning outputs, incident archives, and operator-curated context. Sibling to `mrs-ot-agent-src/` (the bot's CODE + cron runtime state) — this directory is what the bot LEARNS and what humans TEACH it._

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
```

See [`solution-design.md`](solution-design.md) for flywheel goal, problems, metrics, and improvement proposals.

## Quick navigation

| Looking for... | Go here |
|---|---|
| **Cluster registry** (TL surface) | `auto-learnings/patterns/failure-patterns.md` |
| **Archive indexes** (cluster→archive mapping) | `incidents/resolved-{sevs,posts,alerts}/INDEX.md` |
| 4-week trend synthesis | `auto-learnings/digests/TREND-4-week-*.md` |
| Per-week summaries | `auto-learnings/digests/2026-W<NN>.md` |
| SJD coverage gap catalog | `auto-learnings/patterns/sjd-coverage-map.md` |
| Drafted fix patches | `auto-fixes/YYYY-MM/<slug>.md` |
| Daily learning ledger | `auto-learnings/daily-ledger.md` |
| Chronic-noisy trend tracking | `auto-learnings/noisy-trends.md` |
| OT-specific triage rules (R11-R18) | `human-input-domain/triage-discipline.md` |
| Generic triage methodology (R1-R10) | `human-input-generic/triage-methodology.md` |
| Known OT failure patterns (P-rows) | `human-input-domain/known-patterns.md` |
| Agent design principles (P-001→P-015) | `human-input-generic/principles/INDEX.md` |
| Operator-curated domain knowledge | `human-input-domain/` |
| Per-incident SEV archives | `incidents/resolved-sevs/<YYYY-MM>/` |
| Per-incident post archives | `incidents/resolved-posts/<YYYY-MM>/` |
| Per-incident alert archives | `incidents/resolved-alerts/<YYYY-MM>/` |
| Per-conversation thread summaries | `bot-debugging-threads/<YYYY-MM>/` |
| **War stories** (deep incident narratives) | `war-stories/INDEX.md` |
| Daily orphan fbpkg dumps | `incidents/fbpkg-audits/<YYYY-MM-DD>.json` |

```
mrs-ot-agent-context/
├── README.md                              ← This file
├── solution-design.md                     ← flywheel goal, problems, metrics, proposals, principles
├── auto-learnings/                        (see auto-learnings/INDEX.md)
│   ├── daily-ledger.md                    (append-only operational lessons)
│   ├── noisy-trends.md                    (chronic-noisy tracking: alerts + SEVs + posts in one view)
│   ├── patterns/                          ← cluster registry + knowledge graph + deep-dive catalogs
│   │   ├── failure-patterns.md            ← stable [CL-NNN] cluster registry (TL surface)
│   │   └── INDEX.md                       ← operator entry point (S→M→R→P→D traversal)
│   ├── digests/                           ← weekly + monthly cross-incident synthesis
│   │   ├── 2026-W{17..21}.md              ← per-week digests
│   │   └── TREND-4-week-*.md              ← monthly synthesis
│   └── deep-dives/                        (incident-derived triage examples + deep dives)
├── auto-fixes/                            (bot-proposed fix patches)
├── human-input-domain/                    (OT-specific operator knowledge)
│   ├── known-patterns.md                  (P-rows: known OT failure patterns)
│   ├── triage-discipline.md               (R11-R18 OT-specific quality rules)
│   ├── workloads.md                          (model inventory + ownership)
│   ├── ownership.md                       (team routing)
│   └── 2026-05-16-*.md                    (expert observations, SJD gaps, SEV audit)
├── human-input-generic/                   (reusable across projects)
│   ├── triage-methodology.md              (R1-R10 generic quality rules)
│   ├── principles/                        (P-001→P-015 agent design principles)
│   └── report-templates/                  (crisp-report-style.md)
├── incidents/
│   ├── resolved-sevs/<YYYY-MM>/           (<level>-<date>-S<id>.md + README + INDEX)
│   ├── resolved-posts/<YYYY-MM>/          (<date>-W<id>.md + README + INDEX)
│   ├── resolved-alerts/<YYYY-MM>/         (<pri>-<date>-A<id>.md + README + INDEX)
│   ├── open.md                            (active incidents the team is working on)
│   └── fbpkg-audits/<YYYY-MM-DD>.json
├── bot-debugging-threads/<YYYY-MM>/       (per-thread conversation summaries)
└── war-stories/                           (deep incident narratives — investigation journey + durable lessons)
    └── INDEX.md                           (catalog of war stories)
```

## Taxonomy

| Layer | Directories | Purpose |
|---|---|---|
| **Solution design** (operator + bot) | `solution-design.md` | Flywheel goal, guiding metrics, problem inventory, design principles, improvement proposals |
| **Distilled patterns** (bot-generated) | `auto-learnings/` | Cross-incident synthesis, cluster registry, operational lessons |
| **Raw archives** (bot-generated) | `incidents/resolved-*/`, `incidents/fbpkg-audits/` | One-file-per-incident; durable record of WHAT happened |
| **Operator-curated priors** (human-written) | `human-input-domain/` | OT-specific: ownership, models, known patterns, triage rules R11-R18 |
| **Generic methodology** (human-written) | `human-input-generic/` | Reusable: triage methodology R1-R10, agent principles, report templates |
| **Per-conversation rollups** | `bot-debugging-threads/` | Per-thread distillations from operator-bot debugging sessions |
| **Bot-proposed fixes** | `auto-fixes/` | Fix patches the bot generated (not yet shipped) |
| **War stories** | `war-stories/` | Deep narratives of significant incidents — investigation journey, false starts, technical breakthroughs, durable lessons. Teaching artifacts for new oncall. |

## What's NOT here

- **Cron prompts** — `../mrs-ot-agent-src/team_bot/cron-jobs/`
- **Cron runtime state** — `../mrs-ot-agent-src/state/` (moved out of context 2026-05-17)
- **Bot identity files** — `../mrs-ot-agent-src/agent_identity/`
- **Bot CODE** (capabilities, src/) — `fbcode/pe_mrs_ml/mrs_ot_agent/`
- **Concept glossary** — `../mrs-ot-agent-src/deep-dives/concepts.md`
- **P-rows** — `../mrs-ot-agent-src/known_patterns.md` (canonical; `human-input-domain/known-patterns.md` is the context copy)

## Conventions

- **Append-only IDs:** `auto-learnings/patterns/failure-patterns.md` uses CL-NNN IDs. Never renumber, never reuse.
- **Monthly archive rotation:** all per-incident archives live in `<dir>/<YYYY-MM>/`. No deletion; sl history preserves everything.
- **Push target = `master`.** Never `--to remote/default`. See `~/notes/users/dennyzhang/cheatsheets/notes-repo-operations.md`.
