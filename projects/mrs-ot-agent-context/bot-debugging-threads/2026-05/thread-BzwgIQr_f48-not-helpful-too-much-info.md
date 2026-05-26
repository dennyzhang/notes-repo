# Thread Summary: Daily-Brief Too Verbose — Prompt Rewrite

_Source: spaces/AAQAVOjYc80 thread `BzwgIQr_f48` · 6 messages · 2026-05-18T15:25–15:27Z_
_Summarized: 2026-05-18 23:43 PT · last-msg-time: 2026-05-18T15:27:29Z_

## What was discussed

Denny flagged that the daily-brief output was "not helpful — too much info." The bot diagnosed the bloat (20 equal-weight SEV rows, L4 name-dumps, diffs section, speculative WP links) and identified what signal got buried. Denny approved a rewrite.

## Key decisions made

- (2026-05-18T15:25Z) Current brief shape is information-as-firehose; needs structural rework.
- (2026-05-18T15:27Z — "Do it") Rewrote `daily-brief.md` cron prompt. Landed at commit `cb51f4762f38` on `remote/master`. Key changes:
  - **≤20 lines hard-rule** (was unbounded; today's was ~50 lines)
  - **3-bucket SEV structure**: 🔴 NEW TODAY, ⚠️ NEEDS NUDGE (>7d untouched), 📊 in-progress counts only
  - **Diffs section dropped entirely** (visible in Phab natively)
  - **L4 dumps → count only** with a `meta CLI` link for full list
  - **WP links**: high-confidence only; speculative "possibly related to" links forbidden
  - **Self-check gate question added**: "Does this tell the reader what to DO?"
- Next fire: Tuesday 2026-05-19 morning. If still bloated, iterate again.

## Files / artifacts touched

| path | what changed |
|---|---|
| `mrs-ot-agent-src/cron-prompts/daily-brief.md` | full structural rewrite per above rules |

## Cluster / pattern references

_(no cluster IDs cited)_

## Followup items (not yet done)

1. Verify Tuesday 2026-05-19 brief output is ≤20 lines and action-oriented — Denny, informal check

## Cross-refs

- SEVs discussed: S665323 (new today, calvinwoo), S660507 (12d untouched), S663935, S658165 — used as concrete examples for what should surface
- Posts: _(none)_
- Related threads: _(none)_
