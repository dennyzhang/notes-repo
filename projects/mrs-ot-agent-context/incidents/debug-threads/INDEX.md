# Debugging Threads

Per-gchat-thread summaries written by `ot-thread-summarizer` cron (hourly, 4h-quiet threshold).

## Convention

- **Path:** `<YYYY-MM>/<type>-<YYYY-MM-DD-HHMM>-<thread-id>-<slug>.md`
- **Type prefix:**
  - `auto-` — bot handled autonomously (no human correction needed)
  - `human-` — human intervened to correct bot behavior or provide missing context
- **Timestamp:** first message time in PT (HHMM = 24h format)
- **Cross-reference:** should cite `[CL-NNN]` cluster ID when thread is about a known failure pattern

## Flywheel metric: human-involvement ratio

The percentage of `human-` threads should **trend toward zero** over time. This is the single best measure of whether the autonomous flywheel is working — each human intervention should produce a learning that prevents the same intervention next time.

| Week | Total | Auto | Human | Human % | Notes |
|---|---|---|---|---|---|
| _(backfill from existing 143 threads pending)_ | | | | | |

Target: human-involvement ratio below 20% within 3 months. If it rises above 30% for 2 consecutive weeks, trigger a flywheel review.

## Classification rules

A thread is `human-` if ANY of:
- Operator corrected the bot's triage verdict, cluster attribution, or root cause
- Operator provided context the bot should have found on its own (e.g., "why you wait")
- Operator flagged a missing rule, wrong routing, or quality regression
- Bot explicitly asked for direction when it should have acted (Act-don't-ask violation)

A thread is `auto-` if ALL of:
- Bot completed triage without operator correction
- Any operator messages were confirmatory ("ok", "thanks", "good") not corrective
- No new rules/principles were created from the interaction

## Legacy files

Files created before 2026-05-25 use the old convention (`thread-<id>-<slug>.md`, no type prefix, no timestamp). Reclassification happens lazily — when a legacy file is referenced during triage, the thread-summarizer re-summarizes with the new convention.
