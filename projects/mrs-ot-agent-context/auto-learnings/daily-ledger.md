# OT Bot Debugging Learnings Ledger

Auto-maintained by `ot-daily-learning-debugging` cron.
Symlink: `~/.myclaw-ot-bot/spaces/AAQAVOjYc80/learnings.md` → this file.

**Ordering:** newest entries first (reversed 2026-05-25).

---

## 2026-05-26 (L47–L49) — New entries this run

### L47
- **Type:** operational
- **Trigger:** ot-sev-monitor 2026-05-25T21:56 re-processed S659877 ("19-day-old stale SEV, last updated 2026-05-09; previously classified T4, pruned, resurfaced via tag query") + S660706 (preemptive launch-tracking SEV, also previously classified R18). Both had been diagnosed and added to `diagnosed_ids` in an earlier run, then pruned from the state, causing re-processing.
- **Learning:** When pruning `diagnosed_ids`, ONLY remove IDs for SEVs that are confirmed closed/resolved or >30 days stale. NEVER prune open/in-progress SEVs just because they temporarily drop from the 3-day candidate query window. Open-but-out-of-scope SEVs (R18/T4/preemptive) that get pruned will resurface on future runs and waste scope_check cycles. Prune condition should be: `(sev_status == RESOLVED OR age_days > 30)` — not just "absent from this run's candidate set".
- **Action:** Appended to ledger + amended ot-sev-monitor prompt (Learned Rule 2, 2026-05-26)
- **Rollback:** `sqlite3 myclaw.db < cron-prompt-backups/ot-sev-monitor__20260526T151046Z.txt`

### L48
- **Type:** operational
- **Trigger:** ot-alert-monitor 2026-05-26T02:59 diagnosed ig_feed_recs_ifr_t2i_retrieval (holdout 875620176) as DETECTOR_BROKEN on both Cluster A (holdout SPARSE_DELTA) and Cluster B (AGG). Root cause: retrieval models publish FULL_SNAPSHOT only; any `e2e latency sparse delta` or `dense_delta` detector configured on a `_retrieval` model is structurally misconfigured with no data source.
- **Learning:** Add fast-path in ot-alert-monitor step 4: if `model_type_name` ends in `_retrieval` AND alert_type contains `sparse_delta` or `dense_delta` → classify immediately as R16 FALSE_ALARM / DETECTOR_BROKEN (NO ACTION). Retrieval models publish FULL_SNAPSHOT only; SPARSE_DELTA/DENSE_DELTA detectors will always fire false positives. Skip T1–T4 investigation entirely. Saves 1–2 API calls + inference time per occurrence.
- **Action:** Appended to ledger + amended ot-alert-monitor prompt (Learned Rule 3, 2026-05-26)
- **Rollback:** `sqlite3 myclaw.db < cron-prompt-backups/ot-alert-monitor__20260526T151050Z.txt`

### L49
- **Type:** operational (meta — prompt-update mechanism)
- **Trigger:** Direct prompt inspection 2026-05-26 08:07 PT: ot-sev-monitor has only 1 rule in "Learned Rules (auto-appended)" (2026-04-29); ot-alert-monitor has only 2 rules (both 2026-04-29). All ledger entries L29–L46 claimed to "amend cron X prompt (Learned Rule N, date)" — none of those amendments are present in the live sqlite prompts. The step-3 regex still has bare `ATS` (not `\bATS\b` from L29). All 10+ operational learnings that should have been applied are inert.
- **Learning:** The prompt-amendment step in this cron has been silently failing since at least L29 (2026-05-22). Root cause unknown (possible sqlite quoting failure, possible prior failed writes that didn't abort). Two fixes needed: (1) **Immediate**: operator must manually re-apply Learned Rules 2–11 for ot-sev-monitor and Rules 3–5 for ot-alert-monitor (from L29–L46) — too large for this single run. (2) **Structural**: after each prompt UPDATE in this cron, re-SELECT the changed section and grep for the appended rule text before logging "amended" in ledger. If grep fails → log ERROR, do NOT record "amended" in ledger entry.
- **Action:** Appended to ledger. L47+L48 applied in this run (today's rules only). Historical L29–L46 rules require separate operator-driven re-sync pass. No rollback needed (this entry is ledger-only).
- **⚠️ OPERATOR ACTION REQUIRED:** `cron-prompt-backups/ot-sev-monitor__20260526T151046Z.txt` + `ot-alert-monitor__20260526T151050Z.txt` contain the pre-today-amended versions. A bulk re-sync of L29–L46 rules should be applied before next Monday's shift-summary.

---

## Validator Discrepancies

### 2026-05-26
- validator_discrepancy_count_today = 0
- No `⚠ Validator found` markers in any of today's raw_responses. All validators reported as "unavailable (cron context)" across all runs. No auto-loop items this run.

---

## 2026-05-25 (L45–L46) — New entries this run

### L45
- **Type:** operational
- **Trigger:** ot-sev-monitor 2026-05-25T05:05 self-reported: "S666880 and S667443 were erroneously identified as new candidates due to a list-comparison error — they were already in `diagnosed_ids`. Duplicate notifications sent." Affected SEVs received two bot GChat replies each.
- **Learning:** diagnosed_ids set membership check can fail due to int/str type mismatch or in-memory vs file-state divergence, causing duplicate notifications. Fix: (1) normalize all SEV IDs to `str(sev_id)` at both write and read time; (2) after building new-candidate set, re-load diagnosed_ids from persisted JSON for a second-pass check before any notification is sent; (3) if candidate passes in-memory check but fails file check → skip, log `duplicate-guard=triggered`, add to in-memory set.
- **Action:** Appended to ledger + amended ot-sev-monitor prompt (Learned Rule 11, 2026-05-25)
- **Rollback:** `sqlite3 myclaw.db < cron-prompt-backups/ot-sev-monitor__20260525T151105Z.txt`

### L46
- **Type:** operational
- **Trigger:** S667358 "IG Relevance T20 H100 Scribe Over Quota" was open 2026-05-22 12:08 PDT through 2026-05-25 08:07 PDT (~68h unmitigated). ot-alert-monitor correctly classified ≥3 separate model-clusters (2144816217, 2134319967, 2133539495) as CL-003 UPSTREAM_INFRA referencing S667358 — but no run ever surfaced an escalation nudge about the upstream SEV's age.
- **Learning:** When root_cause_sev is open > 48h (time_mitigated=null, created > 48h ago), ot-alert-monitor GChat reply should append: "⚠️ Upstream SEV S{id} has been In Progress for >48h — consider paging upstream oncall if escalation hasn't happened." This is additive to the CL-003 classification, not replacing it. Without this, a long-running upstream SEV generates indefinite OT alert noise with no pressure to resolve.
- **Action:** Appended to ledger + amended ot-alert-monitor prompt (Learned Rule 5, 2026-05-25)
- **Rollback:** `sqlite3 myclaw.db < cron-prompt-backups/ot-alert-monitor__20260525T151105Z.txt`

---

## Validator Discrepancies

### 2026-05-25
- validator_discrepancy_count_today = 0
- No `⚠ Validator found` markers in any of today's raw_responses (05:57 run explicitly noted "validator=unavailable (cron context)"). No auto-loop items.

---

## Pending Pattern Proposals (not yet landed in known_patterns.md)

| Proposed ID | Name | Source Learning | Status |
|---|---|---|---|
| P56 (proposed L33, 2026-05-23) | STUS startup fails: removed MTIA module in fire-app | L33 | Proposed 2026-05-23; operator review needed |
| P57 (proposed L35, 2026-05-23) | DPP session 20-day max lifetime → planned restart → TRANSIENT_NOISE | L35 | Proposed 2026-05-23; operator review needed |
| P58 (proposed L39, 2026-05-24) | TorchElastic/elastic-agent hang (RUNNING+0mvai_metrics+no error — same outer as P44) | L39 | Proposed 2026-05-24; py-spy distinguisher from P44; operator review needed |
| P59 (proposed L26, 2026-05-21) | GIL deadlock trainer: RUNNING MAST + silent mvai_metrics ≥7h | L26 | Proposed 2026-05-21; recheck P-ID before landing (current max=P55) |
| P60 (proposed L27, 2026-05-21) | ZippyDB residual lag ≤24h post-mitigation (amends P58 falsifier) | L27 | Proposed 2026-05-21; note P58 now used for elastic-agent hang; re-ID needed before landing |
| Scribe downsampling (proposed L30, 2026-05-22) | Scribe requestLevelDownsample misapplied to non-USCA OT route | L30 | Proposed 2026-05-22 as "P55" — ID taken (RES flooding); needs new ID (≥P56) before landing |

---

## 2026-05-24 (L43–L44) — Morning pass (08:07 PDT)

### L43
- **Type:** operational
- **Trigger:** ot-sev-monitor 2026-05-24T08:03 — run added 89 NEW IDs to diagnosed_ids (81 scope_check=false drops + 8 R18 drops + 1 new SEV S667620) vs prior state of 49 IDs at 06:54. Indicates state reset between runs. Not self-reported in run summary — operator had no visibility into the anomaly.
- **Learning:** When a single run adds >40 new IDs to diagnosed_ids (anomalous expansion beyond the normal 1–5 new/run cadence), include `state_expansion_anomaly=true` in the run summary header with prior_count, new_count, and delta. Enables operators to detect state resets without grep-scanning. In this instance, all 89 additions were out-of-scope drops (no duplicate notifications), but operator should verify on each such event.
- **Action:** Appended to ledger + amended ot-sev-monitor prompt (Learned Rule 9, 2026-05-24)
- **Rollback:** `sqlite3 myclaw.db < cron-prompt-backups/ot-sev-monitor__20260524T151147Z.txt`

### L44
- **Type:** operational
- **Trigger:** ot-sev-monitor 2026-05-24T08:03 — S667620 classified UNKNOWN/NEEDS_INVESTIGATION with confidence:low (root-cause: not found). Bot sent a gchat reply (URL present) but the reply contained no explicit "inconclusive" marker and no retry flag. SEV triage stalls without auto-recovery.
- **Learning:** When triage produces UNKNOWN/NEEDS_INVESTIGATION with confidence:low: (1) gchat reply MUST include "🔎 Bot triage inconclusive — manual investigation required"; (2) set `retry_on_next_run=true` in state JSON so next hourly run re-attempts with updated SEV context; (3) do NOT auto-tag until confidence ≥ medium — incomplete triage is not a tagging signal (R19).
- **Action:** Appended to ledger + amended ot-sev-monitor prompt (Learned Rule 10, 2026-05-24)
- **Rollback:** `sqlite3 myclaw.db < cron-prompt-backups/ot-sev-monitor__20260524T151147Z.txt`

---

## Validator Discrepancies

### 2026-05-24
- validator_discrepancy_count_today = 0
- No `⚠ Validator found` markers in any raw_responses from the 24h window. All validators reported as "unavailable (cron context)". No auto-loop items this run.

---

## Pending Pattern Proposals (not yet landed in known_patterns.md)

| Proposed ID | Name | Source Learning | Status |
|---|---|---|---|
| P55 (proposed L30, 2026-05-22) | Scribe requestLevelDownsample misapplied to non-USCA OT route | L30 | Proposed 2026-05-22; **NOTE: P55 was landed in known_patterns.md as a DIFFERENT pattern (RES SPARSE_DELTA flooding). L30 proposal needs a new ID (P58+ once checked) before landing.** |
| P56 | STUS startup fails: removed MTIA module in fire-app | L33 | Proposed 2026-05-23; operator review needed |
| P57 | DPP session 20-day max lifetime → planned restart → TRANSIENT_NOISE | L35 | Proposed 2026-05-23; operator review needed |
| P58 | TorchElastic/elastic-agent hang (RUNNING+0mvai_metrics+no error — same outer as P44) | L39 | Proposed 2026-05-24; py-spy distinguisher from P44; operator review needed |
| P59 (from 2026-05-21) | GIL deadlock trainer: RUNNING MAST + silent mvai_metrics ≥7h | L26 | Proposed 2026-05-21; pending operator review — recheck P-ID before landing |
| P60 (from 2026-05-21) | ZippyDB residual lag ≤24h post-mitigation (amends P58 falsifier) | L27 | Proposed 2026-05-21; pending operator review — P60 may clash with elastic-agent P58 shift |


---

## 2026-05-24 (L38–L42) — New entries this run

### L38
- **Type:** operational
- **Trigger:** S667488 "Q3'26 | WIWYNN | DELTA | L6 COMPONENT" (hardware supply-chain SEV) triggered ot-sev-monitor step-3 regex via `DELTA` keyword. It false-positived on 6+ consecutive runs across the full day (01:58 → 13:52 PDT), requiring repeated scope_check invocations before being silently dropped each time.
- **Learning:** After a step-3 `DELTA` regex match, add a post-match procurement exclusion: if title contains any of (`WIWYNN`, `L6 COMPONENT`, `L4 COMPONENT`, `supply chain`, `PSU vendor`, `hardware`, `ISCE`) → classify as in_scope=false immediately, silently add to diagnosed_ids without invoking scope_check. Eliminates repeated false-positive processing for hardware procurement SEVs.
- **Action:** Appended to ledger + amended ot-sev-monitor prompt (Learned Rule 6, 2026-05-24)
- **Rollback:** `sqlite3 myclaw.db < cron-prompt-backups/ot-sev-monitor__20260524T081014Z.txt`

### L39
- **Type:** domain (triage discipline / red herring)
- **Trigger:** W1332867342141342 (ot-post-monitor 2026-05-23 12:26 PDT) — bot diagnosed `🔴 PAGE fengzhang1 | P44 GIL hang on reranker 2125081901 | 7h51m stall`. Denny corrected: elastic-agent (TorchElastic/supervisor) hang, not Python GIL freeze. Both show MAST RUNNING + 0 metrics + ckpt CREATING + empty error — identical outer signature.
- **Learning:** MAST RUNNING + 0 mvai_metrics + ckpt CREATING + empty error matches P44 AND elastic-agent hang. Disambiguator: run py-spy stack dump on rank-0 process BEFORE calling P44. If py-spy shows Python main thread in `take_gil` → A1/P44. If py-spy shows TorchElastic/supervisor frozen (supervisor main loop, `_worker_watchdog`, or C-level signal handler) → elastic-agent hang (distinct class). Bot must not conclude P44 without confirming via py-spy. Recovery for both is identical (`kill v<N>` + TMS restart), but attribution differs.
- **Action:** Appended to ledger. P58 proposed (elastic-agent hang as a distinct named pattern). Triage-discipline SKILL.md amendment proposed. NOT yet auto-applied.
- **Implementation delta (proposed):** Add to `known-patterns.md` P44 Falsifier section: "If py-spy main thread shows TorchElastic/supervisor frame (not `take_gil`) → elastic-agent hang (P58), not P44." + new P58 row drafted below.

### L40
- **Type:** operational
- **Trigger:** ot-alert-monitor 2026-05-23 10:01 PDT — facebook_reels_ifu_i2i 2132070936 diagnosed THRESHOLD_MISFIT (FULL_SNAPSHOT detector — model never publishes FULL_SNAPSHOT). Side-note in raw_response: "same model had prior false-positive on DENSE_DELTA 2026-05-08." Bot correctly classified both times but generated no escalation or recommendation to permanently fix the detector.
- **Learning:** When classifying THRESHOLD_MISFIT, check alert_state for prior occurrences on the same model. If ≥2nd time → include PERSISTENT_MISCONFIGURATION notice in the diagnosis reply ("Recurring false-positive. Recommend permanently removing/reconfiguring this detector.") to drive permanent fix. Without this, the bot will silently handle the same false-positive indefinitely.
- **Action:** Appended to ledger + amended ot-alert-monitor prompt (Learned Rule 4, 2026-05-24)
- **Rollback:** `sqlite3 myclaw.db < cron-prompt-backups/ot-alert-monitor__20260524T081014Z.txt`

### L41
- **Type:** operational
- **Trigger:** ot-sev-monitor 2026-05-23 22:54 PDT self-reported in raw_response: "Noted not-caught-by-regex: S667572 'ESR and LSR NE explosion' (no tags, regex miss — L34 add-`NE explosion` candidate for future)." Metric explosion events (NE/gradient/loss explosion) are clear OT training-stage failures that do not match any existing step-3 keyword.
- **Learning:** Add `(?i)\b(NE|gradient|loss)\s*explosion\b` as an additional OR clause in step-3 title regex. "NE explosion" is the common short form in Meta internal SEV titles (NE = numeric explosion = loss/gradient becoming NaN/Inf). This covers the class of training instability SEVs that are currently invisible to the bot.
- **Action:** Appended to ledger + amended ot-sev-monitor prompt (Learned Rule 7, 2026-05-24)
- **Rollback:** see L38 rollback (same backup file)

### L42
- **Type:** operational
- **Trigger:** ot-sev-monitor 2026-05-23 12:59 PDT — S667565 used model identifier "f831018319" (all-hex, looks numeric but is not a valid decimal model_id). Bot went DEGRADED: "v.1 gate blocked full triage. Awaiting xtliao to populate overview with explicit model_id." No fallback, no reply to SEV, indefinite DEGRADED state.
- **Learning:** Non-numeric model identifiers should trigger a structured 3-step fallback: (1) try `meta ai.model-series describe` with identifier as `--model-name` substring; (2) scan SEV description body and tags for decimal numeric model_id; (3) if still unresolvable → post initial reply to SEV asking owner to populate numeric model_id, set confidence=LOW, record `model_id_unresolvable=true` in state JSON for retry on next run. Never leave triage in indefinite DEGRADED with no owner notification.
- **Action:** Appended to ledger + amended ot-sev-monitor prompt (Learned Rule 8, 2026-05-24)
- **Rollback:** see L38 rollback (same backup file)


---

## 2026-05-23 (L33–L37) — New entries this run

### L33
- **Type:** domain (pattern)
- **Trigger:** S667466 — STUS job `mvai-training-online-2140425308` v21 crashed at startup with `ModuleNotFoundError: No module named 'mtia.tools.autotune.afg_fc_tuning.mtia_autotune_types'`. Fire-app `204be32` included `dper_lib/silvertorch/configs/ranking/ranking_disagg_config.py:7` importing a removed MTIA module. STUS never began publish work.
- **Learning:** Distinct new failure class: STUS fails at Python module import due to removed/moved MTIA dependency in fire-app. Symptom set: STUS attempt DEAD within minutes of start (not a hang), `ModuleNotFoundError` in attempt logs (not OOM/timeout/NCG), root trainer healthy (mvai_metrics recent). Fix: fix import + rebuild fire-app. Distinct from P44 (hang) and GPU_OOM patterns.
- **Action:** Appended to ledger. P56 proposal drafted (see 🧠 PATTERN PROPOSALS section below).
- **Implementation delta:** known_patterns.md P56 row (see below).

### L34
- **Type:** operational
- **Trigger:** ot-sev-monitor 2026-05-22 20:53 flagged: "⚠️ Regex gap observed (not actioned): S667453 'High priority QE model not able to start OT' — not tagged mvai-online-training, 'OT' alone not in signal regex (MRS[._-]?OT requires MRS prefix)." S667453 was never surfaced to triage despite being explicitly about online training startup failure.
- **Learning:** Bare `\bOT\b` abbreviation in SEV titles is not in the step-3 signal regex. Add `online\s+training` (case-insensitive) as additional OR clause in the step-3 title regex. Spellings like "start OT", "OT failure" or "not able to start OT" all map to the same domain but are missed.
- **Action:** Appended to ledger + amended ot-sev-monitor prompt (Learned Rule 4, 2026-05-23).
- **Rollback:** `sqlite3 myclaw.db < cron-prompt-backups/ot-sev-monitor__20260523T080956Z.txt`

### L35
- **Type:** domain (pattern)
- **Trigger:** ot-alert-monitor 2026-05-22 19:55 — `facebook_ifr_main_mtml_main 886797001` fired alert for too-few delta snapshots. Bot correctly diagnosed: DPP session hit 20-day (1,728,000s) max lifetime at 18:48 PDT → planned trainer restart → ~72 min delta gap → auto-recovered by 19:06 PDT. Class: TRANSIENT_NOISE.
- **Learning:** DPP session max lifetime expiry is a distinct, predictable TRANSIENT_NOISE pattern. Identifiers: alert fires ~60–90 min after a clean trainer restart (no MAST error, no OOM), `DPP session uptime` near 1,728,000s (exactly 20 days), model health fully restored after bootstrap. Falsifier: DPP uptime < 19d or MAST shows error → different cause.
- **Action:** Appended to ledger. P57 proposal drafted (see below).
- **Implementation delta:** known_patterns.md P57 row (see below).

### L36
- **Type:** operational
- **Trigger:** ot-sev-monitor 2026-05-22 18:03 UTC — `google.chat.message` gchat tool unavailable in cron context. Bot completed full triage for S667466 (STUS ModuleNotFoundError) and S667465 (conveyor recurrence) but delivered diagnoses inline (raw_response only) — no @-mention sent to SEV owners (shuang42, clementc), no gchat thread created.
- **Learning:** When gchat tool unavailable, completed diagnoses must NOT be silently dropped as inline-only. Fallback: (1) try `meta google.chat.message create --space=spaces/AAQAVOjYc80 ...` CLI; (2) if also unavailable, record `notification_status=PENDING_RETRY` per SEV in state JSON and re-attempt on next run.
- **Action:** Appended to ledger + amended ot-sev-monitor prompt (Learned Rule 5, 2026-05-23).
- **Rollback:** see L34 rollback (same backup file).

### L37
- **Type:** domain (triage discipline)
- **Trigger:** S667465 — "mvai/umia_v1_igr conveyor blocked at cogwheel test step" — bot identified as CONVEYOR_REGRESSION with confidence:HIGH in one step because prior incident S666412 had identical root (bamboo/rfe/client.py contextprop headers). D105634504 re-introduced the same bug.
- **Learning:** When a SEV has an exactly-matching prior incident (same root file/path, same symptom class, same impacted pipeline), set confidence=HIGH without full T2/T3 investigation. Evidence requirement: confirmed `prior_incidents≥1` with matching root + current SEV shows same symptom. Shorten investigation depth when pattern is a known recurrence.
- **Action:** Appended to ledger. Triage-discipline SKILL.md proposal (see 🔧 IMPLEMENTATION DELTAS section).

---

## Validator Discrepancies

### 2026-05-23
- validator_discrepancy_count_today = 0
- No `⚠ Validator found` markers in any raw_responses. Validators were reported as "unavailable (cron context)" across all runs. No auto-loop items this run.

---

## Pending Pattern Proposals (not yet landed in known_patterns.md)

| Proposed ID | Name | Source Learning | Status |
|---|---|---|---|
| P55 | Scribe requestLevelDownsample misapplied to non-USCA OT route | L30 | Proposed 2026-05-22; operator review needed |
| P56 | STUS startup fails: removed MTIA module in fire-app | L33 | Proposed 2026-05-23; operator review needed |
| P57 | DPP session 20-day max lifetime → planned restart → TRANSIENT_NOISE | L35 | Proposed 2026-05-23; operator review needed |
| P59 (from 2026-05-21) | GIL deadlock trainer: RUNNING MAST + silent mvai_metrics ≥7h | L26 | Proposed 2026-05-21; pending operator review — recheck known_patterns.md P-ID before landing |
| P60 (from 2026-05-21) | ZippyDB residual lag ≤24h post-mitigation (amends P58 falsifier) | L27 | Proposed 2026-05-21; pending operator review — recheck P-ID before landing |


---

## 2026-05-22 (L29–L32) — New entries this run

### L29
- **Type:** operational
- **Trigger:** S665416 (Wearables "aTSR" matched `ATS`) and S667190 (WhatsApp "WhATS" matched `ATS`) both caused false positives in ot-sev-monitor step-3 regex in the last 24h. Both were correctly dropped at scope_check but wasted manual assessment cycles.
- **Learning:** `ATS` sub-pattern in step-3 regex lacks word boundary — matches substrings "WhATS" in WhatsApp and "aTSR" in Wearables titles. Fix: `ATS` → `\bATS\b`. Preserves legitimate ATS-budget OT SEVs while eliminating both false-positive classes.
- **Action:** Appended to ledger + amended ot-sev-monitor prompt (regex fix in step 3 + Learned Rule 2)
- **Rollback:** `sqlite3 myclaw.db < cron-prompt-backups/ot-sev-monitor__20260522T*.txt` (restore from backup)

### L30
- **Type:** domain (pattern)
- **Trigger:** S667071 "Scribe IFR and Onefeed regressioned by 20%+" — D106006226 applied `requestLevelDownsample=True` (rate=0.45) to non-USCA external `feed_learning_examples_raas_in_feed_reco_request_level` Scribe route → volume -20%+, eag -46%. All IFR/Onefeed OT models affected (fewer negative training examples).
- **Learning:** Scribe downsampling config misapplied to non-USCA external routes is a distinct OT data-degradation failure class. Symptom: Scribe volume drop on `feed_learning_examples_raas_*` routes without trainer failure. Root: sampling config rollout scope error. New P-row warranted (P55 proposed).
- **Action:** Appended to ledger. P55 proposal drafted below. NOT yet landed in known_patterns.md.

**P55 proposal (DO NOT AUTO-APPLY):**
```
| P55 | Scribe requestLevelDownsample misapplied to non-USCA OT route | Scribe volume drop on feed_learning_examples_raas_* routes; eag spike; no trainer failure; IFR/Onefeed OT models show reduced example density | T1 | (1) Check active Scribe SEVs for `requestLevelDownsample` or `downsampling` config changes; (2) Confirm scope of config change (USCA vs non-USCA; external vs internal route); (3) Verify feed_learning_examples_raas_in_feed_reco_request_level volume in Scribe dashboards. P55 confirmed if volume drop correlates with sampling config rollout timing. Falsifier: no sampling config change in last 24h → different Scribe failure class (P02 or P03). | Revert D<diff_id> (the mis-scoped downsampling config); confirm Scribe route volume recovers within 30 min | Scribe/feed-learning owner (config rollout gate); OT training data quality monitoring | 15 min (revert config) | Source: S667071, D106006226, 2026-05-22 |
```

### L31
- **Type:** operational
- **Trigger:** S666505 (`[Preemptive] Launch LTV MVAI migration model`) and S660706 (`[Preemptive] Launch LTV MVAI migration model`) both matched ot-sev-monitor step-3 regex via `MVAI` keyword but were launch SEVs (out-of-pipeline per R18), requiring manual R18 assessment to drop.
- **Learning:** SEV titles beginning with `[Preemptive]` reliably indicate launch/preemptive SEVs that are out-of-OT-pipeline. At step 3 (after regex match): if `title.startswith('[Preemptive]')` → add to `diagnosed_ids` immediately, skip scope_check + R18. Reduces one manual assessment per preemptive launch SEV per run.
- **Action:** Appended to ledger + amended ot-sev-monitor prompt (Learned Rule 3)
- **Rollback:** see L29 rollback (same backup file)

### L32
- **Type:** operational
- **Trigger:** ot-alert-monitor run 2026-05-21 21:58 UTC — `pastry <paste_id>` used to update validator_status in paste. Resulted in paste content unchanged (`validator_status` stayed "pending").
- **Learning:** `pastry <paste_id>` (piping to an existing paste ID) READS existing content — it does NOT overwrite. To update an existing paste, use `meta paste.paste update --paste-id=<id> --content=<new_full_content>`. If `meta paste.paste update` is unavailable in cron context → explicitly set validator field to `🚫 unavailable` directly in the gchat message. Do NOT silently leave "pending". Affected: ot-alert-monitor and ot-post-monitor validator update steps.
- **Action:** Appended to ledger + amended ot-alert-monitor prompt (paste instruction in validator step + Learned Rule 3)
- **Rollback:** `sqlite3 myclaw.db < cron-prompt-backups/ot-alert-monitor__20260522T*.txt`

---

## Validator Discrepancies

### 2026-05-22
- validator_discrepancy_count_today = 0
- No `⚠ Validator found` markers in any of today's raw_responses. Validators were either unavailable (cron context) or not invoked. No auto-loop items this run.

---

## Pending Pattern Proposals (not yet landed in known_patterns.md)

| Proposed ID | Name | Source Learning | Status |
|---|---|---|---|
| P55 | Scribe requestLevelDownsample misapplied to non-USCA OT route | L30 | Proposed 2026-05-22; operator review needed |
| P59 (from 2026-05-21) | GIL deadlock trainer: RUNNING MAST + silent mvai_metrics ≥7h | L26 | Proposed 2026-05-21; pending operator review — note: ID may collide with existing proposals, recheck known_patterns.md before landing |
| P60 (from 2026-05-21) | ZippyDB residual lag ≤24h post-mitigation (amends P58 falsifier) | L27 | Proposed 2026-05-21; pending operator review |


---

## 2026-05-21 (L25–L28) — Reconstructed from previous run output

### L25
- **Type:** operational
- **Trigger:** Two disk-full events (03:52 + 06:55 PDT) on `/dev/vda4` caused state write failures in ot-sev-monitor. Bot self-recovered by pruning 383 `/tmp/pi-bash-*.log` files.
- **Learning:** Add disk pre-check at ot-sev-monitor run start: if free <100MB → auto-prune `/tmp/pi-bash-*.log` (keep newest 50); if post-prune still <10MB → emit DISK_CRITICAL, abort state write, notify operator.
- **Action:** Appended + amended ot-sev-monitor prompt (step 0 DISK PRE-CHECK block added 2026-05-21)
- **Rollback:** `sqlite3 myclaw.db "UPDATE jobs SET prompt=$(cat cron-prompt-backups/ot-sev-monitor__<ts>.txt | ...) WHERE id='ot-sev-monitor';"`

### L26
- **Type:** domain (pattern)
- **Trigger:** `ig_organic_feed_mtml_holdout` 878102693 trainer GIL-hung ≥7h — MAST RUNNING, mvai_metrics zero, S658165 TCPStore pattern.
- **Learning:** GIL deadlock trainer shows: MAST RUNNING + NCCL watchdog silent + mvai_metrics samples stop ≥7h → PAGE immediately, do not wait for auto-resolve. Distinct from P44 (existing pattern) — P44 uses ≥5min sample gap; this observation generalizes P44 for longer-duration hungs.
- **Action:** Appended to ledger; P59 proposed (domain pattern). NOT yet landed in known_patterns.md.

### L27
- **Type:** domain (pattern)
- **Trigger:** `ig_organic_feed_mtml` scribe_read_proxy spike fired 20.5h AFTER ZippyDB S665163 was mitigated.
- **Learning:** P58 falsifier ("no active ZippyDB SEV → different root") is too strict. Check recently-mitigated ZippyDB SEVs in last 24h via `--mitigated-after` — residual lag can persist ≤24h post-mitigation and still indicate CL-003/TRANSIENT_NOISE.
- **Action:** Appended to ledger; P60 proposed (amends P58 falsifier). NOT yet landed.

### L28
- **Type:** operational
- **Trigger:** 10+ ot-sev-monitor runs today used "manual fallback" because buck2/scope_check binary unavailable in cron context.
- **Learning:** Add local `sev_type` JSON allowlist fallback when buck2 unavailable. For `sev_type=Production` borderline SEVs require ≥1 positive MRS marker (tag OR title keyword beyond regex). Manual-only assessment for Production borderlines is unreliable.
- **Action:** Appended to ledger. ot-sev-monitor prompt amendment deferred (L28 not auto-appended — targets cron behavior beyond simple rule text).

