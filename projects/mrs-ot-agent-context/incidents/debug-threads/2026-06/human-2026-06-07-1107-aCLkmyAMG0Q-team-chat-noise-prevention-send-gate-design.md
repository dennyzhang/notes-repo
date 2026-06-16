---
name: human-2026-06-07-1107-aCLkmyAMG0Q-team-chat-noise-prevention-send-gate-design
description: Design session on preventing team-chat noise regression. Bot discovered classify_delivery_route() already exists in team_bot.py, backtested it against today's leaks (both blocked), and proved the gate works. Blocker: daemon doesn't call it yet (myclaw-core wiring needed).
metadata:
  type: human
  thread_id: aCLkmyAMG0Q
  space: spaces/AAQAVOjYc80
  human_involved: true
  first_msg_time_pt: 2026-06-07 11:07 PDT
  last_msg_time_utc: 2026-06-07T18:38:34Z
  msg_count: 15
---

# Thread Summary: Team-Chat Noise Prevention — Pre-Send Gate Design + classify_delivery_route() Proof

_Source: spaces/AAQAVOjYc80 thread `aCLkmyAMG0Q` · 15 messages · 2026-06-07 11:07–11:38 PDT_
_Summarized: 2026-06-07 21:46 PDT · last-msg-time: 2026-06-07T18:38:34Z_

## What was discussed

Operator asked "what mechanism could avoid future regression?" on team-chat noise. Bot proposed a pre-send gate (by shape/source, not content), a single allow-list shared by gate+audit, and PAGE-semantics override. Operator then asked "what could make future potential leakage?" — bot catalogued: (1) context-bleed (same agent handles 1:1 and team mentions, 1:1 context can ride a legitimate-shaped send), (2) narration/meta in mention responses, (3) side-channel artifacts (pastes/tasks/shift gdoc not covered by a chat gate), (4) gate-evasion (prefix trust can be abused), (5) Phase-2 multi-user context isolation. Operator then said "make the solution reliable." Bot read `classify_delivery_route()` in team_bot.py, found it already exists and is well-designed, backtested it against today's two exact leaks (both routed to 1:1 correctly), confirmed fail-open for real alerts. Blocker: daemon bypass — the function's own docstring says the daemon doesn't call it yet. Thread ended with operator asking about a recently-landed myclaw diff and whether it's sufficient.

## Key decisions made

- [11:07 PDT, operator] Thread-routing correction: "you need to reply to this thread per gchat cheatsheet."
- [11:36 PDT, bot] classify_delivery_route() backtest confirmed: today's LEAK#1 ("The root message...") → 1:1; LEAK#2 ("Acting on 8 queued...") → 1:1; real SEV alert → TEAM; unrouted PAGE → TEAM; unknown source → TEAM (fail-open). Gate is correct and proven.
- [11:36 PDT, bot] The reliable solution requires ONE change outside this lane: daemon must call classify_delivery_route() at the single send chokepoint. Three-line integration (tag source, call function, route to returned space). myclaw-core diff, not a unilateral OT-lane edit.
- Residual vectors not covered by the send-gate: side-channel artifacts + Phase-2 context isolation. Named but not blocked by this gate.

## Files / artifacts touched

| path | what changed |
|---|---|
| `pe_mrs_ml/mrs_ot_agent/src/capabilities/team_lane_scope.py` | contains classify_delivery_route() — read-only in this thread |
| D107579040 | in-flight diff (interactive leak fix); mentioned by bot |

## Cluster / pattern references

_(no CL-NNN applicable — agent-design/noise-prevention topic)_

## Followup items (not yet done)

1. Determine whether recently-landed myclaw diff covers the daemon-side wiring of classify_delivery_route(). Owner: dennyzhang. Status: open (operator's last question, unresolved in thread).
2. If not covered: myclaw-core integration diff (3-line chokepoint: source-tag + classify_delivery_route() call + route-to-returned-space). Owner: dennyzhang. Status: open.
3. Context-compartmentalization for 1:1 vs team-surface handlers. Owner: dennyzhang. Status: future (Phase-2 scope).

## Cross-refs

- Related threads: `BRcxJ7gSLzA` (CLAUDE.md ground-truth rule), `qFpXOG-5jhE` (codex cross-model adversarial review)
- Diff: D107579040
- Memory: `team-chat-noise-prevention-architecture`
