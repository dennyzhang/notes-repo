# Thread Summary: STUS model 2132070936 FULL_SNAPSHOT gap — lineage resolution + wait-reduction protocol

_Source: spaces/AAQAVOjYc80 thread `2KD3EVyCv08` · 6 messages · 2026-05-17 05:28–14:22 UTC_
_Summarized: 2026-05-17 21:33 PT · last-msg-time: 2026-05-17T14:22:16Z_

## What was discussed

Bot paged zihengqin for model 2132070936 (umia_hstu_online, role=stus, facebook_reels_ifu_i2i) for FULL_SNAPSHOT absent 22h. Initial triage noted "Root trainer ID not found in STUS metadata — investigation needed" but then asked the operator for direction ("Vote A or B") instead of running the read-only lineage query immediately. Operator replied at 14:07: "Why you wait" — bot immediately ran the query, found root trainer = 877526181 (ankankr, FB Search AI), RUNNING but not producing SNAPSHOTs. Correct page target was ankankr, not zihengqin. Bot shipped R19 (mandatory lineage chain for STUS alerts) and a wait-reduction protocol to RULES.md.

## Key decisions made

- 2026-05-17T14:08: Lineage resolved — root trainer 877526181 (owner: ankankr/FB Search AI), RUNNING, producing CHECKPOINTs but zero SNAPSHOTs. Page target corrected from STUS owner to root trainer owner.
- 2026-05-17T14:21 (operator "Yes. Also how to reduce the unnecessary wait"): R19 added to ot-alert-monitor + ot-sev-monitor — mandatory 5-command lineage chain when role=stus + snapshot gap detected.
- 2026-05-17T14:22: Wait-reduction protocol added to RULES.md — read-only investigation must be executed at first flag, not deferred to operator confirmation.

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../mrs-ot-agent-src/` ot-alert-monitor.md | R19: STUS lineage pre-step (list-upstream-models → mast-job-describe → instance-list CHECKPOINT/SNAPSHOT → model-series metadata) |
| `notes/.../mrs-ot-agent-src/` ot-sev-monitor.md | Same R19 |
| `~/.myclaw-ot-bot/RULES.md` | Wait-reduction protocol: just do read-only queries; only ask before mutations/external posts |

## Cluster / pattern references

- [CL-001] — STUS-visible snapshot gap where root trainer stops FULL_SNAPSHOT while deltas continue; distinct triage path from trainer-stuck cases (different owner, different next-action)

## Followup items (not yet done)

_(none explicitly discussed)_

## Cross-refs

- SEVs discussed: none
- Alerts: OneDetection A1955974 (model 2132070936 FULL_SNAPSHOT missing)
- Related threads: `O_kKd7ADe5g` (format overhaul session, same day)
