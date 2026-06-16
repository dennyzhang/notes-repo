---
name: human-2026-06-11-1151-jnQIWRB-5Gg
description: STUS heartbeat hang for ig_mixed_feed_smsl_esr (2124455849); bot self-corrected MONITOR→PAGE verdict; missed probe on prior job versions; causal direction reversed
human_involved: true
metadata:
  type: project
  thread_id: jnQIWRB-5Gg
  space: spaces/AAQAVOjYc80
  msg_count: 4
  first_msg_pt: "2026-06-11 11:51 PDT"
  last_msg_pt: "2026-06-11 11:55 PDT"
  summarized_pt: "2026-06-11 21:04 PDT"
---

# Thread Summary: ig_mixed_feed_smsl_esr STUS heartbeat hang — bot self-corrects MONITOR→PAGE

_Source: spaces/AAQAVOjYc80 thread `jnQIWRB-5Gg` · 4 messages · 2026-06-11 11:51–11:55 PDT_
_Summarized: 2026-06-11 21:04 PT · last-msg-time: 2026-06-11T18:55:42Z_

## What was discussed

ot-alert-monitor posted a PAGE verdict for model 2124455849 (ig_mixed_feed_smsl_esr) with class REAL_OT_FAILURE: STUS `st_update_service` hanging on `mvai_monitor`/SILVERTORCH heartbeat across multiple consecutive versions (v29 renewal_count=2, v30 same, v31 manual kill, v32 RUNNING). Bot's main-space verdict had called it MONITOR — wrong on both causal direction and severity. Bot self-corrected after reading the cron output.

## Key decisions made

- **Cron verdict: PAGE shreyasver, REAL_OT_FAILURE** (2026-06-11 11:51): recurring ~5h cadence (v29 04:17, v30 09:11, v31 manual, v32 will hang ~15:00-16:00); STUS hangs after 2 renewals → goes silent; S674766 entity-feature max-delay is a consequence, not cause.
- **Bot's main-space verdict was wrong on two counts** (2026-06-11 11:55): (1) causal direction reversed — inferred feature-delay caused trainer stall; actual: STUS hang caused feature-delay; (2) severity: MONITOR vs PAGE — "currently fresh" was just the post-restart window for v32.
- **Probe miss: only checked current RUNNING attempt** (2026-06-11 11:55): stuck stacks were on prior killed versions, one `--version` flag away. Lesson: `meta ai.mast-job error --version=N` for prior versions is the mandatory follow-up when current attempt is empty/RUNNING.
- **Regex miss noted** (2026-06-11 11:55): "OT failing" bare phrasing wasn't matched by the scope regex; caught only by manual probe; `\bOT\s+fail` should fold into the matcher.

## Files / artifacts touched

| path | what changed |
|---|---|
| (none — self-correction + probe-technique memory saved) | — |

## Cluster / pattern references

(failure-patterns.md not accessible — omitting CL IDs per spec)

## Followup items (not yet done)

1. shreyasver: inspect v30 Job Inspector for STUS hang root; engage silvertorch/mvai_ifr if pattern persists past v32
2. Fold `\bOT\s+fail` into alert-monitor scope regex to auto-triage this class

## Cross-refs

- SEVs discussed: S674760, S674766 (entity-feature max delay — consequence)
- Model: 2124455849 (ig_mixed_feed_smsl_esr), root trainer: 2124455858
