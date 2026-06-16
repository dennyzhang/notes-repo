# Thread Summary: S659617/S659631 — mvai/mvai_ig_ranking cogwheel duplicate-job killed-copy error propagation

_Source: spaces/AAQAVOjYc80 thread `8tivqmMMCqI` · 3 messages · 2026-05-05 16:07–16:11 PDT_
_Summarized: 2026-06-02 10:43 PT · last-msg-time: 2026-05-05T23:11:36Z_
human_involved: false

## What was discussed

Bot cluster triage of 2 linked SEVs (S659617 + S659631), both on mvai/mvai_ig_ranking conveyor (started 09:28 PDT 5/5). Conveyor blocked; IGR Trunk Stability SLI freshness degrading. GChat reads to IG spaces returned empty due to known CLI outage. Root: cogwheel duplicate-job dedup path kills one copy of a job and propagates that killed job's error as the canonical conveyor result, even though another duplicate succeeded. DeltaOnlyPublisher downstream inherits the wrong job reference from the killed copy → publish fails. Rerun 8197.4 was in progress at triage time. Validator confirmed with minor caveat: dkotfis routing is from config, not SEV metadata; DeltaOnlyPublisher/Online_train_publish naming inconsistency is editorial only.

## Key decisions made

- Cogwheel duplicate-job error propagation identified as deterministic root cause (2026-05-05 16:09 PDT); affects every run until framework patched — clementc owns
- Suggested fix: file bug in cogwheel killed-copy error handler; manually reference succeeded job as bypass if 8197.4 rerun blocked (2026-05-05 16:09 PDT)

## Files / artifacts touched

| path | what changed |
|---|---|
| cogwheel duplicate-job error handler | Root cause location (exact path unverified due to GChat DEGRADED) |
| DeltaOnlyPublisher job-selection logic | Downstream victim — inherits wrong job reference |

## Cluster / pattern references

_(omitted — not verified against failure-patterns.md)_

## Followup items (not yet done)

1. File cogwheel bug for killed-copy error propagation in duplicate-job dedup path — owner: clementc
2. Confirm 8197.4 rerun success to verify theory and unblock conveyor

## Cross-refs

- SEVs discussed: S659617, S659631, S658492
- Posts: none
- Related threads: `iWxQwfivBXM` (S658492, same mvai_publish_pipeline signal class)
