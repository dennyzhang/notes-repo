# Thread Summary: m2145491885 correct triage — entitlement oversubscription + publisher broken

_Source: spaces/AAQAVOjYc80 thread `IvNOsU_I0u8` · 4 messages · 2026-05-22 21:43–21:55 UTC_
_Summarized: 2026-05-22 23:47 PT · last-msg-time: 2026-05-22T21:55:27Z_

## What was discussed

Denny delivered the correct root cause for m2145491885 (correcting MyClaw's two prior wrong triages in G209qbn4dsk). MyClaw captured the lesson and rewrote the triage-discipline gotcha file.

Real root cause (per Denny's Workplace comment at `2026-05-22T21:43:56Z`):
1. **Entitlement oversubscription**: `reels_retrieval_main_online_qe` — 7 jobs consuming 192 GPUs, 3 starved including this one; `under_supply: Yes`. v36 showed RUNNING with 0 tasks.
2. **Publisher broken**: v34 hit Gloo timeout in `weights_delta_publisher.py::_should_push_delta`. v35 had port 46145 held by orphaned process. Zero `dai_modelstore` publishes → snapshot 117255 stuck CREATING.
3. Detector alert `Invalid Detector - No Data` is a separate misconfiguration, not part of the oncall.

## Key decisions made

- `2026-05-22T21:55:15Z` (Denny): "wrong triage. I have nailed it and commented in the posts. learn from it" — MyClaw committed two lessons to memory
- Lesson 1: job-local checks first (`under_supply`, allocated_tasks, previous-attempt stderr, `dai_modelstore` publishes) BEFORE any fleet-wide SEV story
- Lesson 2: "snapshot stuck CREATING" → first hypothesis is "this job's publisher is broken," not "infra is broken"
- Lesson 3: naming S-numbers without verified blast radius == fabrication

## Files / artifacts touched

| path | what changed |
|---|---|
| `memory/gotcha_ipnext-sv-capacity-stuck-creating.md` | Rewritten as correction record (original IPNext-SV story was wrong) |
| `memory/gotcha_triage-discipline.md` | Added lesson from this incident + prior |

## Cluster / pattern references

_(omitted — failure-patterns.md not present)_

## Followup items (not yet done)

_(none — Denny closed by commenting on the Workplace post directly)_

## Cross-refs

- SEVs discussed: S667329/S667355/S667348 (mentioned by MyClaw as wrong hypothesis; not causally involved)
- Posts: W1314267290126950
- Related threads: `G209qbn4dsk` (the two wrong triages that preceded this)
