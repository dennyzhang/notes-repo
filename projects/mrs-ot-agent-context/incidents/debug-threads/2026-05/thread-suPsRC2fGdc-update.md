# Thread Summary: R20/R21 wrong meta CLI flags, URL 404 bugs, and validator coverage expansion

_Source: spaces/AAQAVOjYc80 thread `suPsRC2fGdc` · 10 messages · 2026-05-17 15:05–17:01 UTC_
_Summarized: 2026-05-17 21:33 PT · last-msg-time: 2026-05-17T17:01:56Z_

## What was discussed

Operator observed three problems in the 09:39 PT human-attention-brief: many URLs returning 404, items needing help had no thread URL (only space root), and the learning section showed topic headers instead of actionable insights. A concurrent backtest exposed that R20/R21 (recurrence-detection rules shipped at 07:30 PT) used `--tags-include-any-of` — a `search` subcommand flag — on the `list` subcommand, causing silent failure with "Unknown option." Operator also caught bot producing a "standing by on pending decisions" list immediately after shipping the wait-reduction protocol (self-contradiction). All bugs confirmed, fixed, and shipped.

## Key decisions made

- 2026-05-17T16:24: R20/R21 meta CLI flags corrected across all 3 monitor crons (`--tags=` + `--title-contains=` for `list` subcommand, not `search` flags); NOTE comments added to prevent re-introduction
- 2026-05-17T16:24: RULES.md hardened — spec-only edits to cron prompts are unverified; must execute one representative query and verify output before claiming "shipped"
- 2026-05-17T17:01: ot-prompt-change-validator extended with 2 new check categories — URL well-formedness (chat/workplace/sevmanager/onedetection patterns must match canonical forms) + learning-bullet insight-quality (must state cause→symptom→fix, not topic-header)

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../mrs-ot-agent-src/` ot-alert-monitor.md | R20/R21 correct `--tags=` + `--title-contains=` flags (lines 138+147) |
| `notes/.../mrs-ot-agent-src/` ot-sev-monitor.md | Same 4 replacements |
| `notes/.../mrs-ot-agent-src/` ot-post-monitor.md | Same 4 replacements |
| `notes/.../mrs-ot-agent-src/` ot-prompt-change-validator.md | URL well-formedness check + learning-insight quality check added |
| `~/.myclaw-ot-bot/RULES.md` | "Spec-only = unverified; execute before claiming shipped" rule |

## Cluster / pattern references

_(none — bug-fix session, not model triage)_

## Followup items (not yet done)

_(none explicitly discussed)_

## Cross-refs

- Related threads: `Y3qbdh2hC20` (URL discipline and validator genesis — same validator extended here)
- Related threads: `O_kKd7ADe5g` (triage format overhaul; same lint regex that missed URL well-formedness)
