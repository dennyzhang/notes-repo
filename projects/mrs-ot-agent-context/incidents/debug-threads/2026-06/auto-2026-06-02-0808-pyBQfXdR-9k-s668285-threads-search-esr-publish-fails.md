---
human_involved: false
thread_id: pyBQfXdR-9k
thread_name: spaces/AAQAVOjYc80/threads/pyBQfXdR-9k
msg_count: 4
date_range: 2026-06-02 08:08–08:12 PDT
summarized: 2026-06-03 10:43 PDT
last_msg_time: 2026-06-02T15:12:12Z
---

# Thread Summary: S668285 — Threads Search ESR Publish Fails (MVAI Base Layer Breaking Change)

_Source: spaces/AAQAVOjYc80 thread `pyBQfXdR-9k` · 4 messages · 2026-06-02 08:08–08:12 PDT_
_Summarized: 2026-06-03 10:43 PT · last-msg-time: 2026-06-02T15:12:12Z_

## What was discussed

Postmortem digest for S668285 (mvai_publish_pipeline, L3, Closed): Threads Search ESR recurrent publish fails for 72.5h (2026-05-26 to 2026-06-01). The SEV was caused by a MVAI base layer change introducing incompatibility with the long-running barrier code path — the refresh flow had moved to a newer app layer that triggered this path, while the prod flow remained on an older layer that did not. Three independent validators confirmed all digest claims verbatim.

## Key decisions made

- Root cause confirmed: MVAI base layer change broke long-running barrier path for newer-app-layer consumers only (2026-06-02T15:08:28Z).
- Hot-patch applied: `mvai_app_d497b9a08d5f48598eb96dd58547474b:2` via D106836117; long-term fix to land in MVAI base layer.
- Pattern P59 proposed: "MVAI base layer breaking change on newer app layer publish path" — all 3 validators confirmed novelty vs. P58, P32, and all 58 existing P-rows.

⚠️ P59 ID CONFLICT: Thread `2H833FI-UDg` (same day, 08:11 PT) independently proposes P59 for a different pattern (ESR item streaming silent death). Both claims use P59 — one must be renumbered. Operator must verify max P-row number in known_patterns.md before landing either.

## Files / artifacts touched

| path | what changed |
|---|---|
| (none — postmortem digest output; no notes files edited in thread) | — |

## Cluster / pattern references

(omitted — P59 unverified/conflicted; see Followup)

## Followup items (not yet done)

1. Resolve P59 ID conflict with thread `2H833FI-UDg` — check actual max P-row in known_patterns.md and assign distinct IDs before landing either pattern.
2. Land fix D106836117 into MVAI base layer (tracked with MVAI team — no task linked).
3. MVAI to add publish-flow integration tests covering long-running barrier path.

## Cross-refs

- SEVs discussed: S668285
- Posts: (none)
- Related threads: `2H833FI-UDg` (P59 ID conflict)
