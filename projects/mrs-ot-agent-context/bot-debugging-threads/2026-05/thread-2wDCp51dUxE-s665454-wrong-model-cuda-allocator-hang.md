# Thread Summary: S665454 Triage — Wrong Model Attribution + CUDA Allocator D-State Hang

_Source: spaces/AAQAVOjYc80 thread `2wDCp51dUxE` · 6 messages · 2026-05-20T16:51–19:10 UTC_
_Summarized: 2026-05-20 23:45 PT · last-msg-time: 2026-05-20T19:10:18Z_

## What was discussed

The SEV digest cron triaged S665454 ("Threads Retrieval U2M OT DPP workers deadlocked") but attributed it to the wrong model (m2129246926 / threads_feed_mtml ranking instead of m2124122280 / ig_textpost_feed_u2m_retrieval). Denny caught the mismatch ("shouldn't you debug mvai-training-online-2124122280?"), then asked for live triage. The correct root cause is a two-layer CUDACachingAllocator SIGABRT + elastic agent D-state hang — completely different from the bloom_index overflow theory the cron published.

## Key decisions made

- **Correct model confirmed: m2124122280 + m2124793203 + m2124428748** (19:02 UTC): `flow_model_type=ig_textpost_feed_u2m_retrieval` matches SEV title "Threads Retrieval U2M"; cron took Opsmate's model_id reference at face value without cross-checking `flow_model_type`.
- **Real root cause: CUDACachingAllocator INTERNAL ASSERT + D-state hang** (19:10 UTC): Layer 1 = `CUDACachingAllocator.cpp:3316 free_block SIGABRT` (exitcode -6, all 3 jobs); Layer 2 = subprocess enters D-state (uninterruptible kernel sleep) during cleanup → MAST sees top-level process alive → never retries. NOT bloom_index overflow.
- **T265777384 (armandsauzay) is the fix** (19:10 UTC): flagged NO_PROGRESS that morning. Structural fix: `exit_w_cleanup()` missing on `ChildFailedError` path / SJD SIGKILL gap. Same fix unblocks S665478 (Reels LSR MB9 hangs, same class).
- **New discipline rule minted** (19:10 UTC): before locking in a model_id for a SEV triage, verify `flow_model_type` and oncall against SEV title. Mismatch = Opsmate's reference is wrong.

## Files / artifacts touched

| path | what changed |
|---|---|
| `incidents/resolved-sevs/...` | No archive written — triage was live debug, not postmortem-archive run |

## Cluster / pattern references

- W21 mega-learning #5 — `exit_w_cleanup()` missing on `ChildFailedError` + SIGABRT handler hang + SJD SIGKILL gap (same class as S665478)

## Followup items (not yet done)

1. Escalate T265777384 to armandsauzay — structural fix, NO_PROGRESS, recurrence 4× in 1 week (owner: Denny)
2. Cross-link S665454 ↔ S665478 in SEV manager as duplicate-class (Li Lu confirmed same root)
3. Add model attribution discipline rule to cron prompt: verify `flow_model_type` before locking model_id

## Cross-refs

- SEVs discussed: S665454, S665478
- Related threads: `dfL20Dft3XU`, `UH1t_Fwjom4` (same session's earlier cron runs)
