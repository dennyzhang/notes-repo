---
name: task-provenance-flywheel-completion-contract
description: Principle #19 (provenance) added to cheatsheet + swept all auto-filers; flywheel back-half gaps codified as 5-point completion contract in autonomous-workflow cheatsheet
human_involved: true
---

# Thread Summary: Task provenance principle + flywheel completion contract

_Source: spaces/AAQAVOjYc80 thread `sts0WrNeOBM` · 25 messages · 2026-06-07_
_Summarized: 2026-06-07 14:57 PT · last-msg-time: 2026-06-07T21:57:45Z_

## What was discussed

Thread started with two operator thread-behavior corrections ("reply to the thread"). Bot then ran a provenance enforcement sweep across all auto-filers to check whether each names its originating job. Operator pushed bot to codify flywheel back-half gaps (the "complete + reliable, no laziness" question) — bot identified 6 gaps, operator said "why ask" when bot offered to fold them in, triggering immediate action.

## Key decisions made

- **Principle #19 (provenance / traceability): every auto-filed artifact names its origin.** Committed to `autonomous-workflow-principles.md:261`. (msg: 2026-06-07T21:52:23Z, verified from file)
- **Filer sweep result: 4 of 5 already complied** — ot-alert-monitor ("Auto-filed by ot-alert-monitor"), ot-fleet-health systemic-gap/chronic ("auto-detected/filed by ot-fleet-health"), ot-knowledge-distillation (`knowledge-distillation:` prefix + `ot_bot_autodraft` tag). **One gap: ot-cron-health-guard** named the failing job but not the filer → fixed (`eee345c19743`). (msg: 2026-06-07T21:49:01Z)
- **Flywheel completion contract added to autonomous-workflow cheatsheet** (commit `07e69e7db788`): 5 back-half gaps:
  1. "done" = landed + live (post-restart, verified from job_runs) + re-ran the flagging check + durable (mirrored/pushed)
  2. Did-it-work loop: every fix tagged with the metric it defends, re-checked next cycle
  3. Drive to land, not queue: expand auto-apply allowlist; class-sweep in same pass
  4. Mechanical-by-default: hook/code/test is the deliverable; prose only when no mechanism possible
  5. Watch your own organs: monitor expected artifact production, not just exit status
- **"Why ask" correction fired** (msg: 2026-06-07T21:55:34Z) — bot offered to fold the gaps into the cheatsheet; operator said "why ask"; bot proceeded immediately. Canonical act-don't-ask violation.

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../autonomous-workflow-principles.md` | #19 provenance rule added (commit `7ccc7e80e09b`) |
| `notes/.../team_bot/capabilities/ot-cron-health-guard filer` | "Auto-filed by ot-cron-health-guard" in task title (commit `eee345c19743`) |
| `notes/.../cheatsheets/autonomous-workflow-cheatsheet.md` | "improvement-flywheel completion contract" section (commit `07e69e7db788`) |

## Cluster / pattern references

_(No cluster IDs cited — not verified against failure-patterns.md)_

## Followup items (not yet done)

1. **Did-it-work mechanism** — the contract says mechanical-by-default but point #2 (did-it-work regression loop) is still prose. Next build: generalize the feedback-coach ↑/↓ delta into a self-edit ledger so the flywheel becomes self-correcting. Flagged in cheatsheet inline.
2. **Notes-remote push still blocked** by the 232-commit diverged stack (provenance commits are local + mirror to fbcode but not remote-backed yet).

## Cross-refs

- SEVs discussed: none
- Related threads: `HmhHRX5Mb4I` (same session — provenance principle applied to task-filer audit), `z65y10B925Y` (cron-health-guard rename context)
