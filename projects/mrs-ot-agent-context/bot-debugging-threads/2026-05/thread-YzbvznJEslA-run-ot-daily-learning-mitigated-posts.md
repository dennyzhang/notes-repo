# Thread Summary: ot-daily-learning-mitigated-posts — no learning generated + detection rule expansion

_Source: spaces/AAQAVOjYc80 thread `YzbvznJEslA` · 7 messages · 2026-05-15 08:05–08:24 PT_
_Summarized: 2026-05-16 13:31 PT · last-msg-time: 2026-05-15T08:24:01Z_

## What was discussed

Denny triggered `ot-daily-learning-mitigated-posts` and asked if any learning was generated. The bot reported zero eligible posts — no `#resolved` hashtags in the last 7 days in the mrs.ot Workplace group. Investigation revealed the detection rules were too strict: 1 post (Denny's May 8 post `1320976936663716`) had `is_accepted_answer=true` and a teammate's plain-English resolution comment ("this issue has been resolved by re-enabling X") — neither signal was in the cron's check list. Denny approved expanding the detection rules.

## Key decisions made

- **[2026-05-15T08:23:37Z] Decision: add Checks 5 + 6** to `ot-daily-learning-mitigated-posts`:
  - *Check 5:* `is_accepted_answer == "true"` on any comment (Workplace native "mark as answer") — high precision
  - *Check 6:* Plain-English phrase match (`resolved by`, `this issue is resolved`, `fixed by re-enabling`, etc.) — lower precision, marks digest as `degraded` with `weak_resolution_signal`

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/notes/users/dennyzhang/mrs-ot-agent/` (canonical cron prompt) | Added Checks 5 + 6 to resolution-detection section |
| `~/fbsource/.../mrs_ot_agent/...` (fbcode mirror) | Mirrored |
| `myclaw.db` jobs table | `ot-daily-learning-mitigated-posts` prompt updated (new len 14688) |

## Cluster / pattern references

_(none)_

## Followup items (not yet done)

1. Verify Checks 5+6 fire correctly on next daily run (21:30 UTC) — the May 8 `is_accepted_answer` post is 6+ days old and still outside the 24h window, so first real test will be a newer accepted-answer post. Owner: bot (passive). Status: pending next eligible post.
2. Submit cron-prompt changes via fbcode diff (blocked on `ot-notes-fbcode-sync` sync pass). Owner: bot. Status: pending.

## Cross-refs

- Related thread: `i9qJr_e-TYU` (same session — cron path fix ran first)
- Workplace post: `1320976936663716` (Denny's May 8 post with is_accepted_answer=true — ground truth example)
