# Thread Summary: Cron Health Alerts + Notes Push Discipline Fix

_Source: spaces/AAQAVOjYc80 thread `1cVsOXXSa34` · 5 messages · 2026-05-16T19:24–19:47 UTC_
_Summarized: 2026-05-16 23:33 PT · last-msg-time: 2026-05-16T19:47:57Z_

## What was discussed

Two ot-cron-health-watch alerts fired simultaneously. First: `ot-sev-monitor` ordering_bug — S659877 was posted to main space BEFORE R18 (scope gate) ran, producing a 2-min retraction. Second: `ot-notes-commit-push` new_failure — Mononoke B2xTreegroup2 protocol error (intermittent flap, 4th recurrence today). Thread resolved both and hardened push discipline in RULES.md and all 3 monitor crons.

## Key decisions made

- **ordering_bug root cause** (2026-05-16T19:24:01Z): R18/scope checks must run BEFORE main-space 🚨 post, not after. Fix already landed at 10:04 PDT; S659877 alert predated the fix. Hysteresis: suppress re-alert for 7 days.
- **Notes push target is `master`, not `remote/default`** (2026-05-16T19:25:35Z): push divergence was user error (wrong bookmark), not infra. Corrected immediately.
- **RULES.md push discipline rule added** (2026-05-16T19:47:57Z — confirmed by final message): 6-step push + verify procedure (edit notes → commit → push to master → sl cat verify → mirror to fbcode → setup-cron-jobs.sh → verify daemon).
- **model_name anti-pattern rule added to all 3 monitor crons** (same): verified: notes commit `3100d0e30763`, fbcode mirrored, daemon DB updated (3/3 rows returned).
- **Verification triple-check discipline** (same): after any cron-prompt edit, run notes/fbcode/daemon grep trio — all 3 must agree.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/.myclaw-ot-bot/RULES.md` | NEW §"Notes-repo push discipline" — 6-step procedure + cron-edit order |
| `ot-alert-monitor.md` | model_name anti-pattern rule added |
| `ot-sev-monitor.md` | model_name anti-pattern rule added |
| `ot-post-monitor.md` | model_name anti-pattern rule added |
| notes commit `3100d0e30763` | All 3 cron edits + RULES.md |

## Cluster / pattern references

(none — operational/bot-internals thread; no cluster IDs applicable)

## Followup items (not yet done)

(none — all 3 actions executed in-thread; "Act don't ask" was Denny's instruction at 2026-05-16T19:47:15Z and was followed)

## Cross-refs

- SEVs discussed: S659877 (ordering_bug trigger, hysteresis active)
- Related threads: `6pKeH_XqjcE` (format redesign that established the locked format now being verified), `djeMtzxvfbU` (push-to-master lesson first surfaced)
