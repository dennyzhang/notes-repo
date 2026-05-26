# Thread Summary: brief link discipline, markdown URL syntax, and ot-prompt-change-validator genesis (Option A)

_Source: spaces/AAQAVOjYc80 thread `Y3qbdh2hC20` · 13 messages · 2026-05-17 16:16–16:39 UTC_
_Summarized: 2026-05-17 21:33 PT · last-msg-time: 2026-05-17T16:39:52Z_

## What was discussed

Operator gave three sequential feedback items on the ot-human-attention-brief output: (1) items needing help must link back to the source gchat thread — not the space root, but the full `room/<space>/<thread_id>` URL; (2) URLs should use markdown `[text](url)` syntax so the URL is invisible in rendered gchat and the message stays concise; (3) learning bullets must include both a derivation URL (where bot learned it) and an artifact URL (where it was codified). Operator then asked how to reduce human involvement in validating prompt changes; bot proposed Options A/B/C; operator chose A. Bot built and shipped ot-prompt-change-validator.

## Key decisions made

- 2026-05-17T16:17: Brief prompt spec updated — clickable gchat thread URL per triage/SEV item; URL format `https://chat.google.com/room/AAQAVOjYc80/<thread_id>` (never bare space root)
- 2026-05-17T16:18: Two-URL rule for learning bullets — derivation URL (source of learning) + artifact URL (notes file or commit); format: `<emoji> <topic> -- <insight> -- <derivation_url> · <artifact_url>`
- 2026-05-17T16:29 (operator feedback "URL should be attached to the text"): Markdown `[text](url)` syntax mandated; raw URL text in visible bullet content prohibited
- 2026-05-17T16:39 (operator "A"): ot-prompt-change-validator built and deployed — fires every 10 min, sha256-hashes each cron prompt, on hash change spawns subagent to simulate past triage against new prompt, FAIL → gchat alert (24h dedup per cron), PASS → silent, INCONCLUSIVE suppressed unless 3+ consecutive

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../mrs-ot-agent-src/` ot-human-attention-brief.md | Link-discipline spec: thread URL format, two-URL learning rule, markdown syntax |
| `notes/.../mrs-ot-agent-src/` ot-prompt-change-validator.md | New cron — 10-min sha256 diff + subagent simulation (Option A) |

## Cluster / pattern references

_(none)_

## Followup items (not yet done)

_(none explicitly discussed)_

## Cross-refs

- Related threads: `suPsRC2fGdc` (URL 404 bugs exposed by these same briefs; validator coverage expanded there)
- Related threads: `AO2s1nqf19w` (re-fires used to test the new prompt)
