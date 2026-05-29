# Thread Summary: URL Discipline Fix (W<id>) + S668263 Adjacent SEV Triage

_Source: spaces/AAQAVOjYc80 thread `hYjLARUjdDU` · 8 messages · 2026-05-27T04:54–04:57Z_
_Summarized: 2026-05-28 21:45 PT · last-msg-time: 2026-05-27T04:57:38Z_

## What was discussed

Denny flagged that "Post: W1332867342141342" in a cron output was an invalid reference — `W<id>` is internal shorthand, not a URL. Bot resolved it (Workplace permalink) and fixed ot-daily-learning-debugging to CLI-resolve all `W<id>` tokens before writing into the ledger. In the same turn, bot triaged S668263 (CFR HSTU predictor_eval SessionOrchestrator failure) as adjacent/not-OT-owned.

## Key decisions made

- [04:57Z] W1332867342141342 resolved to https://fb.workplace.com/groups/mrs.ot/permalink/1332867342141342/ (m2125081901 P44-vs-elastic-agent-hang correction from 2026-05-24).
- [04:57Z] URL discipline rule landed in ot-daily-learning-debugging: bare `W<id>` forbidden; must resolve via `meta workplace.post describe --post-id=<id> -o json | .url` before writing ledger. Rule applies to S/D/T/A/f/W/model-id tokens.
- [04:57Z] S668263 (CFR HSTU predictor_eval, SessionOrchestrator `csid_0` single-session-state loss → 100% fan-out) assessed as NOT OT-owned; owner is Feed_ecosystem_core_modeling; bot stays in monitor mode.

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../cron-jobs/ot-daily-learning-debugging.md` | Step 4a: URL resolution table for W<id> and other token shapes |
| `memory/gotcha_url-discipline-bare-ids.md` | New: W<id> must be CLI-resolved before citing in ledger |

## Cluster / pattern references

_(no OT training failure cluster applies to S668263 — it is mvai_publish_pipeline / predictor_eval, not OT training)_

## Followup items (not yet done)

_(none)_

## Cross-refs

- SEVs discussed: S668263 (CFR HSTU, L4, predictor_eval SessionOrchestrator bug, not OT-owned)
- Posts: W1332867342141342 (m2125081901 P44-vs-elastic-agent correction)
- Related threads: none
