# Thread Summary: Triage audit review + auditor design + llu6 communication style

_Source: spaces/AAQAVOjYc80 thread `2w5Schmk83U` · 35 messages · 2026-05-19 15:50–17:20 PDT_
_Summarized: 2026-05-19 23:42 PT · last-msg-time: 2026-05-19T17:20:56Z_

## What was discussed

Denny reviewed the cron's triage of a `scribe_read_proxy.client_lag_in_seconds` alert for model 2134319967 (ig_organic_feed_mtml). The verdict (🟢 NO ACTION) was correct, but the bot missed S665163 (ZippyDB throttle SEV) and S665692 (a recent SEV naming model 2134319967 in its title). The thread then expanded into designing a post-hoc auditor cron with 4-tier escalation, creating two draft cron files, and analyzing llu6's oncall-log communication style for improvement ideas.

## Key decisions made

- **2026-05-19 16:02:35**: Auditor escalation ladder established: 🟢 Pass (silent) → 🟡 Self-heal (auto-correct) → 🟠 Operator nudge (batched into morning brief) → 🔴 Page (only when verdict would lead to wrong operator action).
- **2026-05-19 16:03:56** (Denny "C"): Option C chosen — prototype auditor dry-run against today's 6 triages first, then formalize spec.
- **2026-05-19 16:32:40**: Denny asked for draft files dumped inline; confirmed reviewing both ot-triage-auditor.md and heavy-cron-stagger-proposal.md.
- **2026-05-19 ~17:20**: 8 communication patterns from llu6's log queued to backlog as improvements for ot-alert-monitor + ot-shift-summary.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/draft-cron-edits/ot-triage-auditor.md` | Created: 11 R-rules for post-hoc triage auditing |
| `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/draft-cron-edits/heavy-cron-stagger-proposal.md` | Created: stagger 3 heavy crons from concurrent :41 to :05/:20/:35 |

## Cluster / pattern references

- [CL-003] — scribe_read_proxy.client_lag_in_seconds classified under downstream-infra reliability; alert auto-resolved as expected transient Scribe lag

## Followup items (not yet done)

1. Land ot-triage-auditor.md into fbcode as inactive cron spec — awaiting Denny review + approval (batch at end-of-week)
2. Decide on heavy-cron stagger Y/N — awaiting Denny Y/N
3. Land 8 llu6 communication-style improvements into triage cron prompts — queued in weekly batch

## Cross-refs

- SEVs discussed: S665163 (ZippyDB CAS throttle, missed by cron), S665692 (Feed LSR 2134319967 NE spikes, mitigated 5/18, missed by cron), S663572 (NE quality, 5/11, ongoing)
- Related threads: `m71mRGuB0b4` (continuation of auditor/cron design discussion same day)
