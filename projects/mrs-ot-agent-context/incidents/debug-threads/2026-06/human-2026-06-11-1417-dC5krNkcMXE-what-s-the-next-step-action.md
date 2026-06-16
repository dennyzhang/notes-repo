---
thread_id: dC5krNkcMXE
space: spaces/AAQAVOjYc80
human_involved: true
msg_count: 70
date_range: 2026-06-11T21:17–23:25 UTC
---

# Thread Summary: Code-Mitigation Auto-Fix Gate + RE Throttle Retry Fix

_Source: spaces/AAQAVOjYc80 thread `dC5krNkcMXE` · 70 messages · 2026-06-11_
_Summarized: 2026-06-11 17:04 PT · last-msg-time: 2026-06-11T23:25:22Z_

## What was discussed

Operator nudged the bot ("shouldn't you look into the source code and file auto-fix task and diff?") after the post-monitor stopped at "MONITOR / UPSTREAM_INFRA / retry in 30-60min" for an `ig_textpost_feed_u2m_retrieval` failure caused by RE throttle (`remote_execution.engine.prod` SR collapsing 0.6%→0.05%). The thread then expanded into a full structural fix: why the bot consistently lags on filing auto-fix tasks for code-mitigable failures, and how to close the loop permanently.

## Key decisions made

- **(21:24, T275529522)** Auto-fix task filed. **(21:47, D108337795)** Draft diff: retry-with-backoff (3×, exponential + full jitter) on configerator throttle at `config_utils.py:175-196` keyed on `ConfigoRateLimitedError`/`ConfigoTimeoutError`/`ConfigoInternalError`. 11 tests pass, pyre clean. Reviewers: ziyuejoeysun + lupaul + #minimal_viable_ai.
- **(21:52–22:00)** Code-Mitigation Auto-Fix Gate built into all 3 monitors (post/alert/sev). Root cause of lag: monitors only auto-filed tasks for misconfig/detector classes; code-mitigable UPSTREAM_INFRA verdicts filed nothing. The gate forces the question for both REAL_OT_FAILURE and UPSTREAM_INFRA, filing a task only when an in-code fix exists in MRS-OT-owned tooling (`code_mitigation: yes → task`; `none: not-MRS-OT-code → route upstream`).
- **(22:00)** `record-triage-event.sh` backstop: helper gains `--class`/`--code-mitigation` args; records `MISSING`+loud-warn if a code-rooted class arrives without a decision. Additive column, backward-compat.
- **(22:14–22:16)** `--upstream-confirm` required field for UPSTREAM_INFRA verdicts: every upstream verdict must carry a runnable query or resolvable link proving the root from data (P-017 decisive metric). Missing → `MISSING`+warn. Live proof: first real run (light_cli cluster, S674839) correctly classified `code_mitigation: none:not-MRS-OT-code`, routed upstream, validator caught real root on S674930 (code regression `7964ca94`, not RE).
- **(22:09, operator)** Class label is NOT the filter — `code_mitigation` is: UPSTREAM_INFRA with in-code resilience angle → file; UPSTREAM_INFRA with no in-code angle (pure capacity/data outage) → no task, upstream oncall + P-017 metric.
- **(22:13, operator)** Upstream observability requirement: "query or log link which can confirm it's the upstream issue — very valuable." Operationalizes P-017 at triage time.
- **(23:22–23:25)** Auto-fix highlight wired into fleet-health digest (`render-fleet-digest.py`): `🔧 auto-fix: N drafted → review/land D... · N abandoned`. Filtered: abandoned/rejected diffs excluded from review/land CTA. Golden test passes. Verified on real state: D107966514 shown, D107959319 (ABANDONED masking-reject) correctly excluded.

## Files / artifacts touched

| path | what changed |
|---|---|
| `configerator/src/minimal_viable_ai/config_utils.py` | D108337795: retry-with-backoff on configerator throttle |
| `record-triage-event.sh` | `--class`/`--code-mitigation`/`--upstream-confirm` args; MISSING enforcement |
| post-monitor, alert-monitor, sev-monitor (sqlite) | Code-Mitigation Auto-Fix Gate + upstream-confirm requirement wired |
| `render-fleet-digest.py` | Auto-fix highlight line; abandoned-filter |

## Cluster / pattern references

- [[digest-numbers-compute-in-code-reconcile-assert]] — the exact anti-pattern: LLM-narrated count (91) vs deterministic count (~25)
- [[code-mitigation-autofix-gate]] — architecture described: monitors → `[OT auto-fix]` task → drafter → draft diff
- P-016 (full ownership: source-dive → task → diff) — the prose expectation that was being skipped
- P-017 (decisive metric for upstream hand-off) — operationalized via `upstream_confirm` field
- P-018 (bot resolves every fetchable value) — applied at the class-filter explanation step

## Followup items (not yet done)

1. `ot-triage-auditor` surface: must **re-derive** code-rootedness from ground truth (not read the `code_mitigation` column), flag `MISSING` rows → active ping to operator 1:1. Red-team identified: the helper backstop depends on `--class` being passed, which is skippable under triage focus → external re-derivation is the real terminal backstop. Status: specified, not built.
2. Notes→fbcode sync for monitor prompt changes and `record-triage-event.sh` (staged in sqlite; live next daemon tick, not yet mirrored to notes repo).

## Cross-refs

- Tasks: T275529522
- Diffs: D108337795
- SEVs referenced: S674219 (EAG scribe drain, pure-upstream no-code-fix example), S674839, S674930
- Related threads: (close-the-thread ritual run at 22:18)
