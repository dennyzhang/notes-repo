# Thread Summary: Post-close silence rule — brevity discipline

_Source: spaces/AAQAVOjYc80 thread `cAYCph-1ob0` · 9 messages · 2026-05-31 04:27–05:03 UTC_
_Summarized: 2026-06-01 05:45 PT · last-msg-time: 2026-05-31T05:03:59Z_

## What was discussed

Denny challenged why the bot sent an unsolicited follow-up recap after a task was already closed and verified on master. Bot acknowledged it was a "status reflex" with no new signal. Denny requested the close protocol, which produced a rule: closed/done-and-verified → silent. The thread also captured Denny's own close-protocol audit noting the bot couldn't retrieve the root message via API and flagging an edge-case: proactive top-level messages only if all four conditions hold (time-sensitive + new signal + no owning cron + Denny not already in an active thread on same topic).

## Key decisions made

- **2026-05-31T04:29:25Z** Denny: `close the thread` → bot added post-close-silence as anti-pattern #4 to `comms/gchat.md` § Brevity.
- **2026-05-31T04:30:24Z** Folded the new trigger into the existing `suppress-noise` memory (no duplicate memory).
- **2026-05-31T05:03:21Z** Denny confirmed the rule: proactive top-level messages require all four gates (time-sensitive, new signal, no owning cron, no active thread on same topic). Fails any → stay in own thread or HEARTBEAT_OK.

## Files / artifacts touched

| path | what changed |
|---|---|
| `cheatsheets/comms/gchat.md` § Brevity | Added anti-pattern #4: post-close recap |
| memory: `suppress-noise` | Trigger folded in; no new file spawned |

## Cluster / pattern references

_(omitted — no [CL-NNN] verified in failure-patterns.md)_

## Followup items (not yet done)

_(none discussed)_

## Cross-refs

- SEVs discussed: none
- Posts: none
- Related threads: none
