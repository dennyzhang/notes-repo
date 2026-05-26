# Thread Summary: ot-daily-learning-mitigated-posts debug — detection-rule expansion

_Source: spaces/AAQAVOjYc80 thread `YzbvznJEslA` · 7 messages · 2026-05-15_
_Summarized: 2026-05-17 14:31 PT · last-msg-time: 2026-05-15T08:24:01Z_

## What was discussed

Denny asked to run `ot-daily-learning-mitigated-posts` immediately after the notes-restore session. When the cron produced no output (HEARTBEAT_OK), Denny flagged it as suspicious ("something is wrong — let's debug it"). Bot investigated: the cron's sole resolution signal was `#resolved` hashtag; zero posts in the mrs.ot Workplace group carried that tag in the last 7 days. However, one post (Denny's May 8 post) had `is_accepted_answer=true` (Workplace's native "mark as answer" button), which the cron did not recognize. A second signal — teammate commenting "this issue has been resolved by re-enabling X" in plain English — was also missed. Denny chose Option 1: expand the detection rules by adding Check 5 and Check 6.

## Key decisions made

- **Check 5 added** (2026-05-15T08:23:37Z, Denny selected option 1): detect `is_accepted_answer == "true"` on any comment → high-confidence resolution signal; dominant signal in mrs.ot group.
- **Check 6 added** (same): plain-English phrase match (`"resolved by"`, `"this issue is resolved"`, `"fixed by re-enabling"`, etc.) → lower-precision, marks digest as `degraded` with `weak_resolution_signal` for validator scrutiny.
- **No-output-is-not-broken** clarified: cron returning `HEARTBEAT_OK` with zero eligible posts is correct behavior when nothing matches the criteria — not a silent failure.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/notes/users/dennyzhang/mrs-ot-agent/cron-jobs/ot-daily-learning-mitigated-posts.md` | Added Check 5 (is_accepted_answer) and Check 6 (plain-English phrase match) |
| `~/fbsource/.../mrs_ot_agent/team_bot/cron-jobs/ot-daily-learning-mitigated-posts.md` | Mirrored from notes |
| `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db` (jobs table) | Prompt updated in-place (UPDATE 1 row, new len 14688) |

## Cluster / pattern references

_(no CL-NNN patterns apply — this thread is about bot cron configuration, not training failures)_

## Followup items (not yet done)

_(none explicitly discussed — the Check 5+6 fix was applied immediately and Denny closed the loop)_

## Cross-refs

- SEVs discussed: _(none)_
- Posts: Denny's May 8 mrs.ot post (Workplace ID 1320976936663716) — the post that exposed the is_accepted_answer blind spot
- Related threads: `i9qJr_e-TYU` (same morning session — preceded this thread)
