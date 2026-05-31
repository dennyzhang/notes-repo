# Thread Summary: DPP Rotation Hypothesis → Pattern-Registry Task → ot-post-monitor Silent Drop Bug

_Source: spaces/AAQAVOjYc80 thread `yF_aMB00xMk` · 71 messages · 2026-05-27_
_Summarized: 2026-05-28 22:45 PT · last-msg-time: 2026-05-27T19:40:43Z_

## What was discussed

Three distinct topics merged in this thread. (1) DPP session rotation: Denny asked to confirm DPP rotation as root cause for a "training example age over 1 hour" alert. MyClaw confirmed the 20-day Zeus TTL rotation signature on 886797001 v68/0 (verbatim log: `1728118s > 1728000s limit`), but failed to check the ACTUAL current job — 2123944781 (Hao Sha's MC12 arm3). That job had no rotation log; Paul Lu's comment at 11:47 PT ruled out DPP starvation; real cause was trainer-bound throughput. (2) Verifiable-triple registry: Denny called out that every "known pattern" claim needs an exact ODS metric path + exact log substring + ≥3-job spot-check. T273151495 filed, plan doc written. (3) ot-post-monitor silent drop: MyClaw's cron processed Hao Sha's post (paste P2352902191 created, state updated) but emitted no gchat notification and FABRICATED a fake thread URL in the run summary. T273158617 filed.

## Key decisions made

- (2026-05-27T18:41, Denny) "this should be a major follow-up" — pattern claims need verifiable triple before bot rule is added.
- (2026-05-27T18:46, Denny) "File a meta task, create a plan, then work on it" → T273151495 filed.
- (2026-05-27T19:33, Denny) "Don't reply directly! Delete your reply" — MyClaw had posted to a multi-person thread (space/SEV); reply deleted.

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../auto-fixes/2026-05/19-pattern-registry-verifiable-triple.md` | Plan doc, 6-phase design |
| memory: `feedback_known-pattern-validation.md` | New memory: pattern claims need metric+log+≥3-spot-check |
| memory: `gotcha_cron-silent-drop-debug-recipe.md` | New memory: search state files + cross-space before assuming cron skipped |

## Cluster / pattern references

_(No confirmed cluster IDs — omitted)_

## Followup items (not yet done)

1. T273151495 Phase 2 (DPP-rotation pilot): tighten Scuba filter + cross-join rotation events × example-age UBN ±30 min to get true noise-reduction number.
2. DPP rotation precondition gate: add `starvation% > 5%` metric as mandatory precondition before bot applies DPP-rotation classification.

## Cross-refs

- Tasks: T273151495 (pattern registry), T273158617 (ot-post-monitor silent drop)
- SEVs discussed: S667544 (IFR holdout DPP rotation anchor)
- Posts: W1336024098492333 (Hao Sha MC12 arm3 help request)
- Related threads: `3l_SghsIBZE` (UBN pilot)
