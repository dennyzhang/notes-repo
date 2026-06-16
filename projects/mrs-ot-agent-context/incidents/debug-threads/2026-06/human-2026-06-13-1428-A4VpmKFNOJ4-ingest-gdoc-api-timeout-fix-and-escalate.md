---
name: ingest-gdoc-api-timeout-fix-and-escalate
description: ot-ingest-gdoc cron was silently reporting fetch_failed for ~a week without fixing or escalating. Root-caused two bugs (daemon hang + missing revisionId), both fixed live. P-020 encoded.
metadata:
  type: project
  human_involved: true
---

# Thread Summary: `ot-ingest-gdoc` API Timeout — Fix & Escalate, Not Just Report

_Source: spaces/AAQAVOjYc80 thread `A4VpmKFNOJ4` · 91 messages · 2026-06-13 14:28–22:58 PDT_
_Summarized: 2026-06-14 21:04 PDT · last-msg-time: 2026-06-14T01:00 UTC_

## What was discussed

Denny triggered with "!ot-bot did you follow up on the api timeout?" The cron had been emitting `errors: fetch_failed` for ~4 of 6 days (Jun 8-13) with no escalation or fix. Two root causes were found and fixed:

1. **Daemon hang**: `gdocs get --raw-json` for `mrs-ot-reliability-cross-team-followups` (599KB) hangs indefinitely with the daemon; `--no-daemon` returns in 4s. (`--untrusted-authors-mode` was a red herring — ruled out by isolation test.)
2. **Missing `revisionId`**: the Docs API omits `revisionId` for some docs; the no-drift gate had no fallback. Fixed with `sha256(deterministic body render)`.

Denny then corrected the class of failure: the cron itself was the problem — it reported-not-fixed and buried-not-escalated. The recurrence→escalate→auto-fix pattern existed only in triage monitors; infra/sync crons were the blind spot.

## Key decisions made

- **P-020 encoded** (2026-06-13T21:52): every cron that can emit an error must (a) drive a fix or file a deduped `[OT auto-fix]` task, and (b) escalate MAJOR issues obviously (`🚨` to operator 1:1, exempt from batching). Generalized across ALL crons, not just triage monitors. Added to CLAUDE.md.
- **Step 3.9 added to `ot-ingest-gdoc`**: tracks per-source consecutive failures; at ≥2, 🚨-escalates and files a deduped fix task. Resets on success. Verified live in sqlite (`updates=1`).
- **Close-the-thread red-team found 2 real issues**: (a) escalate-obviously decayed into escalate-daily (fixed: 🚨 only on transition + weekly beat, not every run once task is open); (b) `sha256(markdown)` was non-deterministic due to LLM metagen alt-text (fixed: `--image-text-backend none --no-comments`).
- **gdocs fetch-vs-write daemon split** (discovered during close-thread): large fetches need `--no-daemon` (daemon hangs); small writes work via daemon, hang on `--no-daemon`. Captured in gdocs cheatsheet.

## Files / artifacts touched

| path | what changed |
|---|---|
| `ot-ingest-gdoc` cron prompt (sqlite + notes) | `--no-daemon` on fetches, sha256 drift-key fallback, step 3.9 recurrence/escalation |
| `cheatsheets/gdocs/rules.md` | Daemon hang trap, `--no-daemon` write gotcha, revisionId-absent trap |
| Principles: P-020 | New: cron must fix+escalate, not just report |
| Memory: `cron-fix-and-escalate-not-report.md` | New feedback memory |

## Cluster / pattern references

_(No existing CL-NNN matched)_

## Followup items (not yet done)

1. T275785951 — stay open until next 1-2 runs show `errors: none` on both docs; close after verification

## Cross-refs

- Tasks: T275785951
- Related threads: `Nk_Ui4WFn4U` (same session day)
