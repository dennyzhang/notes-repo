---
name: human-2026-06-12-2246-kELsQU-CtLk-detector-broken-next-action-outreach-budget
description: Operator corrected bot's DETECTOR_BROKEN "none" rendering; drove fix to escalation rule + daily-brief routing + operator outreach budget governing rule
metadata:
  type: project
  human_involved: true
---

# Thread Summary: DETECTOR_BROKEN "None" Rendering Fix + Operator Outreach Budget Rule

_Source: spaces/AAQAVOjYc80 thread `kELsQU_CtLk` · 26 messages · 2026-06-12 22:46–23:23 PDT_
_Summarized: 2026-06-13 21:04 PDT · last-msg-time: 2026-06-13T06:23Z_

## What was discussed

Operator caught that ot-alert-monitor rendered DETECTOR_BROKEN/high as next_action=`none` (via dedup — 2 open fix tasks existed). Root cause: detector 4494597707530131 monitors sparse_delta on ig_feedrec_esr_ttsn (879633040), a retrieval/holdout model that structurally produces no sparse_delta. Bot had been silently deduping behind stale open tasks for 18d. Thread drove three rule fixes and a new governing outreach rule.

## Key decisions made

- [05:51:04Z] DETECTOR_BROKEN never renders next_action=`none` — always a fix-driving action: no open task → file; open task exists → `fix pending → T### (open Nd), drive to land`; >7d no progress → escalate
- [05:58:25Z] Operator: "shouldn't you pop to me?" → chronic broken detectors (≥7d) now surface to operator 1:1 explicitly with one-line why + task age + drive-ask (not buried as NO_ACTION)
- [06:01:14Z] Operator: "use daily brief to flag that to me" → alert-monitor stops real-time-popping chronic detectors; daily-brief §4c "Fixes not landing" surfaces open [OT auto-fix] tasks aged >7d once/day
- [06:23:36Z] Operator: "unless it is urgent, you reach out me less frequently. My bandwidth is limited" → governing rule encoded in CLAUDE.md + memory: real-time only for urgent (active PAGE/SEV, irreversible action, emergency); everything else batches into daily brief

## Files / artifacts touched

| path | what changed |
|---|---|
| `ot-alert-monitor` (sqlite, notes) | DETECTOR_BROKEN never-"none" rule; chronic→pop rule; →daily-brief routing |
| `ot-daily-brief` (sqlite, notes) | §4c "Fixes not landing" section added |
| `CLAUDE.md` (live + notes canonical) | Operator outreach budget governing rule added |
| memory `operator-outreach-budget-batch-nonurgent` | Written |

## Cluster / pattern references

- [R19] — sparse_delta DETECTOR_BROKEN on retrieval/holdout models is structural (no data by design); durable fix is model_type-level gate, not per-model task

## Followup items (not yet done)

1. Investigate why D107959319 (cs_omni detector removal) was abandoned; draft model_type-gate diff for all retrieval/holdout sparse_delta detectors — owner: bot driving (no explicit deadline set)

## Cross-refs

- Related threads: `e78lVJptOAI` (upstream_infra evidence rule, same session), `j7iFKgBgtXg` (confirm-upstream-scribe.sh)
