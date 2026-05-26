# Thread Summary: Notes repo push + resolved-SEV naming fix

_Source: spaces/AAQAVOjYc80 thread `pjTRT7ubzUs` · 30 messages · 2026-05-20_
_Summarized: 2026-05-21 01:42 PT · last-msg-time: 2026-05-20T23:57:31Z_

## What was discussed

Denny asked the bot to commit and push the Phase 1+2+3 notes inventory layer (models.md, taxonomy.md, heatmap.md, trending.md + auto-discovery cron specs) to the notes repo. The bot committed locally but repeatedly failed with bare `hg push`, incorrectly diagnosing it as a server-side Bundle2 error. Eventually resolved by using `hg push --to dennyzhang --create` (user-namespace bookmark). In the same session, Denny noticed 5 files in `incidents/resolved-sevs/2026-05/` had inconsistent naming (`SEV-S<id>-<date>.md` vs canonical `L{level}-{date}-S{id}.md`) and asked the bot to fix them. Both resolved and pushed to master.

## Key decisions made

- **`hg push --to dennyzhang --create`** is the correct push command for `fb:notes` — bare `hg push` silently fails or emits Bundle2 error; user-namespace bookmark required. (2026-05-20T23:13:27Z bot message)
- **Resolved-SEV naming convention**: `L{level}-{date}-S{id}.md` where `<date>` = mitigated date in PT, NOT closed date. Documented in `incidents/resolved-sevs/2026-05/README.md`. (2026-05-20T23:57:31Z bot message)

## Files / artifacts touched

| path | what changed |
|---|---|
| `auto-learnings/inventory/` | New dir: README, models.md (~32 OT models seeded), taxonomy.md, trending.md, heatmap.md + proposed-crons/ |
| `incidents/resolved-sevs/2026-05/` | 5 files renamed to canonical convention; 1 duplicate removed; INDEX.md updated (+6 entries); README.md convention clarified |
| Notes cheatsheet | 3 new traps added: bare `hg push` failure, push-bookmark pattern, date-field meaning in SEV convention |

## Cluster / pattern references

_(No OT-triage cluster IDs apply — this is a bot-workflow/tooling thread.)_

## Followup items (not yet done)

1. L23 Deltoid false-positive exclusion in `ot-sev-monitor` step 4 pre-filter — operator action needed; bot flagged at 2026-05-20T23:42:49Z but not yet applied.

## Cross-refs

- SEVs discussed: none
- Related threads: `BzwgIQr_f48` (failure-patterns consolidation, same session day)
