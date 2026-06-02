# War Story #3 — Threads Training Data Blackout (S639956)

**SEV:** S639956 — Threads Online Training Data Breakage
**Level:** L1 | **Owner:** Paskalino Spirollari
**Duration:** Mar 26, 2026 — 10.1 hours (incident), closed Mar 30
**GChat:** spaces/AAQANz3etA8
**Impact:** Training data volume dropped to near zero for ~9 hours across all Threads Feed, TIXU, and Search ranking paths. All Threads relevance models (ESR, LSR, VM MTML, Retrieval) degraded. Engagement metrics: Likes -6.5%, Impressions -4.7%, Reshares -9.5% hourly w/w. ESR P(skip)/P(continue) took days to recover.

---

## The problem in one sentence

A code refactoring diff extracted a method but forgot to return the `ranking_logger` object, leaving it as `None` in the caller — a silent `if ranking_logger is not None` guard skipped all training data logging for 9 hours, breaking OT for every Threads model.

## Why this is a war story

This is the **only L1** in the OT SEV archive. It's also a completely different failure family from the process-exit bugs (War Stories #1 and #2). The lesson here isn't about infrastructure — it's about how a seemingly safe code refactor in the ranking/serving layer silently breaks the entire OT data pipeline, and how the detection gap between "data stopped flowing" and "model metrics degrade" costs hours.

## The cast

- **Paskalino Spirollari** — SEV owner
- **Diff author** (D96993922) — extracted inline code into a helper method. The helper returned `ranked_media` but not `ranking_logger`.
- **Multiple oncalls:** p92_relevance_retrieval, p92_relevance_growth, igml_training_data, igml_data_quality, treehugger_instagram, instagram_server_ci

## The architecture that broke

```
Instagram Django Server (C2 push)
  └─► DistilleryTextPostAppRankerMez.async_rank_media()
       ├─► (1) Rank content for user
       ├─► (2) Create ranking_logger → log model prediction scores
       └─► (3) _async_log_training_data() → Scribe → Muddler tables
                                                       ↓
                                               OT pipeline consumes
                                                       ↓
                                    ESR, LSR, VM MTML, Retrieval models
```

The critical detail: `_async_log_training_data()` is guarded by `if ranking_logger is not None`. This guard was meant as a safety check but became the silent kill switch — when the refactor left `ranking_logger = None`, the guard skipped logging with zero errors, zero alerts, zero log output.

## The diff that broke it

**D96993922** — a "fragment migration" refactoring diff. Extracted inline code from `async_rank_media()` into helper method `_create_lsr_ranking_logger_and_log()`.

The bug:
```python
# BEFORE (inline in async_rank_media):
ranking_logger = create_ranking_logger(...)  # assigned in caller scope
# ... later ...
if ranking_logger is not None:
    _async_log_training_data(ranking_logger, ...)

# AFTER (extracted to helper):
def _create_lsr_ranking_logger_and_log(self, ...):
    ranking_logger = create_ranking_logger(...)
    # ... does work with ranking_logger ...
    return ranked_media  # ← BUG: ranking_logger NOT returned

# In caller:
ranking_logger = None  # initialized at top of method
ranked_media = self._create_lsr_ranking_logger_and_log(...)
# ranking_logger is STILL None
# ...
if ranking_logger is not None:  # ← silently skips ALL logging
    _async_log_training_data(ranking_logger, ...)
```

## Timeline (all times EST, Mar 26)

| Time | Event |
|------|-------|
| ~4:35 AM | D96993922 + D97007645 land via C2 push. Training data volume drops to zero. **No push-blocking alert fires.** |
| ~5:00–6:00 AM | OT pipeline consumes empty data stream. Models drift. NE/calibration alerts fire. |
| 6:41 AM | SEV filed as L3 after oncall confirms calibration anomalies. Upgraded to L2 shortly after. |
| ~8:00 AM | D96993922 identified as suspect via C2 push timing correlation with Scribe volume drop. |
| ~8:30 AM | Diff author acks. Revert diffs prepared (D98295929, D98295913). |
| 8:45 AM | Root cause confirmed. |
| ~10:18 AM | **Upgraded to L1** after confirming complete training data loss across all Threads Feed/TIXU/Search. |
| 10:22 AM | Revert build R99022.2 completed. |
| 11:18 AM | C1 push completed. |
| 12:20 PM | C2 push completed. Training data volume restored. |
| ~12:30–2:00 PM | Corrupted data window blocklisted across all clients (D98319424, D98314468). |
| ~2:00–5:00 PM | Corrupted snapshots banned. OT restarted for all affected prod/holdout models. |
| ~6:56 PM | SEV marked mitigated. Most models recovering. |
| Mar 27–30 | ESR P(skip)/P(continue) slowly recovers over several days. SEV closed Mar 30. |

**Total time from data loss to detection: ~2 hours.** Total time to mitigation: ~8 hours. The 2-hour detection gap was entirely because there was no alert on training data write volume — the breakage was only caught indirectly via model calibration drift.

## The recovery was as complex as the break

Restoring data flow (reverting the diff) was only step 1. The full recovery required:

1. **Revert the diff** — restore `ranking_logger` creation in caller scope
2. **Blocklist the corrupted data window** — 4:00 AM to 12:20 PM across 8+ Scribe clients to prevent OT from training on empty/partial data
3. **Ban corrupted snapshots** — models that trained on the bad window produced bad snapshots that would poison serving
4. **Restart OT for all affected models** — prod and holdout variants of Retrieval, ESR, LSR Main, VM MTML, Debias MTML
5. **Wait for convergence** — ESR P(skip)/P(continue) took days to recover because the model had already learned from the corrupted window before blocklists landed

## The four detection gaps

| Gap | What was missing | Follow-up |
|-----|-----------------|-----------|
| No push-blocking alert on training data volume | Scribe write volume drop during C2 push went undetected | T263890913 (Critical) |
| No direct alert on data volume drop | Only caught via downstream model calibration drift ~2h later | T261613487 (Exploratory) |
| Silent `None` guard | `if ranking_logger is not None` skips silently — no error, no log, no metric | T261646941 (Critical): refactor code to make `None` impossible |
| Claude-driven migration safety | The refactoring was done by Claude/Codex migration tooling. No independent review caught the bug | T261655303 (Critical): add independent bot review for migration diffs |

## Durable lessons

1. **Silent `None` guards are time bombs.** `if x is not None: do_critical_thing()` with no `else: log_error()` means the critical thing can silently stop happening. In a training data pipeline, "silently stop logging" = "silently break all downstream models." Every `None` guard on a critical path needs an `else` branch that screams.

2. **The ranking layer IS the OT data pipeline.** OT oncall thinks of the pipeline as "MAST job → trainer → model." But the data source is the ranking/serving layer — a single diff in `ranker_mez.py` broke training for every Threads model. OT oncall must monitor upstream data volume, not just downstream model health.

3. **Detection gap = impact multiplier.** 2 hours between data loss and first alert. Every hour of delayed detection is another hour of corrupted model training that requires blocklisting, snapshot banning, and multi-day recovery. A push-blocking alert on data volume would have caught this in minutes, not hours.

4. **Recovery from data corruption is multi-step and slow.** Reverting the diff is the easy part. Blocklisting, snapshot banning, OT restarts, and metric convergence took 8+ more hours. ESR took days. Plan for this when estimating time-to-recovery.

5. **Code refactoring is not "safe."** Extracting a method looks harmless. But when the return value changes (or a variable falls out of scope), the caller silently breaks. Migration tooling (Claude/Codex) needs independent review specifically for return-value and scope changes.

## Relationship to other war stories

- **S665454 / S628346 (War Stories #1, #2):** Infrastructure-layer failures (process won't exit). S639956 is a data-layer failure (data stops flowing). Together they cover the two main OT failure families: "job stuck" and "job running but training on nothing."
- **Pattern:** All three share a common shape — a silent failure that existing monitoring doesn't catch, detected only by downstream symptoms (model staleness, calibration drift, QE degradation) hours later.

## Status

**Closed.** Diff reverted, data blocklisted, models restarted. Follow-up tasks carved for alerting (T263890913), code refactor (T261646941), and migration safety (T261655303).

## References

- SEV: https://www.internalfb.com/sevmanager/view/639956
- Root cause diff: D96993922
- Revert: D98295929, D98295913
- Blocklists: D98319424 (Feed/TIXU), D98314468 (Search)
- Impact data: P2261742217
- Follow-ups: T261613567 (test), T263890913 (alert), T261646941 (refactor), T261655303 (migration safety), T261613487 (PBA)
- GChat: spaces/AAQANz3etA8
