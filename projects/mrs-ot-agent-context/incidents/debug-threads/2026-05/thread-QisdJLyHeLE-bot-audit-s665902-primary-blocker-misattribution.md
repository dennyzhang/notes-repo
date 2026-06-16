# Thread Summary: Bot Audit — S665902 Falsely Claimed as Primary Blocker for m878858380

_Source: spaces/AAQAVOjYc80 thread `QisdJLyHeLE` · 9 messages · 2026-05-19_
_Summarized: 2026-05-19 22:41 PT · last-msg-time: 2026-05-19T16:03:42Z_

## What was discussed

Denny reviewed the ot-alert-monitor cron's triage for m878858380 (facebook_cfr_hstu_online, 12.5h FULL_SNAPSHOT gap). The cron claimed S665902 (Conveyor ModuleNotFoundError) was the **PRIMARY BLOCKER** for the model's publish path. The live session (this bot, interactive) rebutted: S665902 affects `cfr_main_feed_mtml_roo_hstu:94407d8` + `light_cli:364f1ea`, while m878858380 v133/v134 runs on `cfr_main_feed_mtml_roo_hstu_v4:6` + `light_cli:3493` — different variant, different bundle. Temporal coincidence (S665902 started 1.5h after last good snapshot) was mistaken for causation.

## Key decisions made

- **[2026-05-19T11:49:34Z]** Bot (live session) corrected cron: PRIMARY cause = Shampoo NaN crash loop (CL-017); S665902 is a RELATED future-release blocker, not the current-job blocker. Verdict should be MONITOR, not PAGE.
- **[2026-05-19T14:55:34Z]** Denny asked to clarify "cron" vs "I" — distinction codified: "cron" = ot-sev-monitor/ot-alert-monitor scheduled job; "I" = live interactive session. Same identity, different execution contexts.
- **[2026-05-19T16:01:20Z]** Denny pushed for "better debugger and auditor" → bot proposed ot-triage-auditor cron architecture + self-critique pre-publish step. Denny chose option (b): dry-run prototype first.
- **[2026-05-19T16:03:22Z]** Auditor dry-run authorized ("B"). Dry-run ran over 6 triages; found 11 misses, 0 verdict-changing, with top recurring patterns: cross-ref step too narrow and PAGE-on-engaged-owner.

## Files / artifacts touched

| path | what changed |
|---|---|
| (no files written) | Auditor dry-run was read-only; improvements pending confirmation |

## Cluster / pattern references

- [CL-017] — Shampoo NaN is the PRIMARY root cause on m878858380; cron incorrectly downgraded it to secondary when S665902 was present
- [CL-001] — Snapshot-stuck-CREATING: S665902 Conveyor regression is a CL-001 sub-mechanism but only for the `cfr_main_feed_mtml_roo_hstu` (non-`_v4`) variant

## Followup items (not yet done)

1. Apply prompt-edit #1 (PAGE guard), #5 (app_layer_pkg variant awareness), #9 (temporal coincidence ≠ causation) — awaiting batch confirmation from Denny (see thread WApKJGlKThc)

## Cross-refs

- SEVs discussed: S665902, S660507
- Related threads: `WApKJGlKThc` (S665902 cron output), `si7PIRLI6Gc` (auditor dry-run findings)
