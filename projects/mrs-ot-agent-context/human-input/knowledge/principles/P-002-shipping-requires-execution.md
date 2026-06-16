# P-002: Shipping Requires Execution

**Statement:** A cron-prompt edit isn't "shipped" until one representative execution validates the new prompt produces the expected output. Commit + push + daemon-update are necessary but insufficient.

**Discovered:** 2026-05-17 (cascade of 5+ silent failures: prompt edits committed, daemon updated, NEXT cron fire revealed prompt did wrong thing — operator catches what self-check missed).

**Why it matters:** Cron prompts are durable specs that fire autonomously. A bug in a prompt fires hourly/daily until caught. Each silent failure burns operator trust + corrupts archive history. Backtest BEFORE shipping is 10× cheaper than fixing after.

**Applies to:** any agent system that mutates durable prompts/configs that fire autonomously.

**Current applications:**
- `ot-prompt-change-validator` cron (every 10min sha256 diff + sub-agent simulation against past raw_response)
- Manual backtest after spec edits — see 2026-05-17 11:18 PT R20-extension where backtest exposed 2 latent bugs in newly-shipped spec
- `ot-daily-learning-mitigated-alerts.md` includes URL-form pre-render check (lint-as-execution)

**Anti-patterns it prevents:**
- 2026-05-17 10:55 PT: P58 cited despite failed falsifier (caught by operator)
- 2026-05-17 11:06 PT: content-grep bulk classify produced cross-ref false positives (self-caught at spot-check)
- 2026-05-17 11:15 PT: R20 local-sweep missed mega-learnings + INDEX false positives (self-caught at backtest)
- 2026-05-17 09:23 PT: R20 R21 flags wrong (silent failure across multiple crons)

**Related principles:** P-007 (citation discipline), P-009 (validator coverage), P-011 (spec vs lint)
