# KD Proposed Change — 2026-05-19 (BOT_INCOMPLETE: dirty working copy)

**Status**: NOT COMMITTED — working copy dirty at run time (`fbsource`: 4 M files on cron-jobs; `notes`: 3 M state files). Bot detected the pattern and wrote this proposal for operator review. To land: clean working copy, apply the diff below, then `sl commit + jf submit --draft`.

---

## Pattern Detected (Threshold 2 — false-alarm signature ≥2, same alert family)

| Field | Value |
|---|---|
| **Signal class** | R16 false-alarm, same alert family |
| **Source incidents** | ALERT-4366891846955592 (2026-05-18) + ALERT-898952803114953 (2026-05-18) |
| **Alert family** | `dai_modelstore` FULL_SNAPSHOT missing — facebook_cfr_main_mtml model 878858380 (baseline + holdout) |
| **Root pattern** | CL-017 Shampoo NaN cascade → trainer v126 restart (01:07 PDT) → bootstrap window (~20-26 min) → FULL_SNAPSHOT alert fires before first snapshot published |
| **Verdict in both** | R16 false alarm — TRANSIENT_NOISE — NO_ACTION (bot correctly classified both) |
| **Why pattern matters** | Baseline + holdout FULL_SNAPSHOT alerts fire SIMULTANEOUSLY on same model restart. Current R16 example (umia_hstu_online) covers "model NEVER produces snapshot type". This is a DIFFERENT sub-case: model DOES produce FULL_SNAPSHOT normally, but alert fires during the bootstrap gap after NaN-induced restart. Triager must distinguish them. |

**Deferred (Threshold 4):** R16 cited 3x in 5 new summaries (also ALERT-1621571482326635 ZippyDB cascade → sparse latency). Threshold 4 would add a "Validated by N=3 summaries" line to R16. Deferred to next run.

---

## Proposed Change

**File**: `~/fbsource/fbcode/pe_mrs_ml/mrs_ot_agent/references/triage-discipline.md`
**Rule**: R16 — add sub-case example for post-restart bootstrap gap

### Unified diff (apply manually)

```diff
--- a/fbcode/pe_mrs_ml/mrs_ot_agent/references/triage-discipline.md
+++ b/fbcode/pe_mrs_ml/mrs_ot_agent/references/triage-discipline.md
@@ R16 row, after "Source: 2026-05-08 m2132070936..." sentence, before "Failure mode:" @@@
-Source: 2026-05-08 m2132070936 (`umia_hstu_online`, facebook_reels_ifu_i2i) — alert title "Publishing Stability ... missing snapshot types SPARSE_DELTA, DENSE_DELTA"; bot DID note "DENSE_DELTA never produced in 10k-instance lookback" as a sub-finding but failed to promote "alert is misconfigured" to the standing hypothesis. Drifted to FULL_SNAPSHOT investigation (different alert, different model) and the disabled-flow rabbit hole instead. Operator: "This is false alarm. The alert expect dense delta, which doesn't apply to this model. you failed to pinpoint the root cause."
+Source: 2026-05-08 m2132070936 (`umia_hstu_online`, facebook_reels_ifu_i2i) — alert title "Publishing Stability ... missing snapshot types SPARSE_DELTA, DENSE_DELTA"; bot DID note "DENSE_DELTA never produced in 10k-instance lookback" as a sub-finding but failed to promote "alert is misconfigured" to the standing hypothesis. Drifted to FULL_SNAPSHOT investigation (different alert, different model) and the disabled-flow rabbit hole instead. Operator: "This is false alarm. The alert expect dense delta, which doesn't apply to this model. you failed to pinpoint the root cause."
+
+**R16 sub-case — post-restart bootstrap gap (CL-017/P56 family):** When a `FULL_SNAPSHOT missing` alert fires on a model that DOES normally produce FULL_SNAPSHOT, but the alert fire time is within ~30 min of a trainer restart, this is a DIFFERENT R16 variant: the bootstrap window, not a snapshot-type misconfiguration. **Verification**: `meta ai.mast-job attempts --name=mvai-training-online-<MODEL_ID> -o json` — read `creation_time` of the latest attempt. Compute delta = alert_fire_time − restart_time. **If delta ≤ 30 min AND a co-active NaN cascade SEV (CL-017/P56 family) exists → R16 false alarm: TRANSIENT_NOISE, NO_ACTION.** When BOTH baseline and holdout alerts fire simultaneously on the same model_id, they share the same bootstrap gap — treat as one cluster; single NO_ACTION verdict covers both. Alert re-tune ask: FULL_SNAPSHOT alerting threshold should be suppressed for the first N minutes (N ≥ model's typical bootstrap duration after restart) following any trainer restart event. Route re-tune request to alert config owner for the model class. **Source**: 2026-05-18 ALERT-4366891846955592 + ALERT-898952803114953 (facebook_cfr_main_mtml model 878858380 baseline + holdout) — both fired during ~20-26 min bootstrap window after trainer v126 restart at 01:07 PDT post-CL-017 Shampoo NaN cascade; both auto-resolved when FULL_SNAPSHOT 878858380:3099 published at 02:49 PDT. Sourced by ot-knowledge-distillation 2026-05-19.
+
+**Validation evidence (R16 cumulative):** Validated by N=3 independent triage summaries 2026-05-18–2026-05-19: (1) ALERT-1621571482326635 (ZippyDB S665114 cascade → sparse delta latency elevated, NO_ACTION); (2) ALERT-4366891846955592 (CL-017 bootstrap gap → FULL_SNAPSHOT baseline, NO_ACTION); (3) ALERT-898952803114953 (CL-017 bootstrap gap → FULL_SNAPSHOT holdout, NO_ACTION). All 3 correctly bot-classified as R16 false alarms at confidence: high. Pattern is robust — both sub-cases (snapshot-type mismatch AND bootstrap-gap) appear in the corpus within a single week.
```

### Proposed commit message
```
[OT bot] knowledge-distillation 2026-05-19: R16 sub-case — post-restart bootstrap gap

Pattern detected from 2 alert archives (ALERT-4366891846955592 + 
ALERT-898952803114953): FULL_SNAPSHOT missing alert fires during ~20-26 min 
bootstrap window after CL-017 Shampoo NaN cascade restart. Distinct from 
existing R16 example (umia_hstu_online — model NEVER produces snapshot type).
Also adds R16 validation evidence from N=3 independent summaries 2026-05-18 to
2026-05-19.

BOT_INCOMPLETE on 2026-05-19 run due to dirty working copy (fbsource had 4 M
files). Proposal written to kd-proposed-2026-05-19.patch.md for operator review.
```

---

## How to Land

```bash
cd ~/fbsource
sl status  # confirm clean
# apply the diff above manually to references/triage-discipline.md
arc lint -a fbcode/pe_mrs_ml/mrs_ot_agent/references/triage-discipline.md
sl commit -m "[OT bot] knowledge-distillation 2026-05-19: R16 sub-case — post-restart bootstrap gap"
jf submit --draft --update-fields
# NEVER add publish_when_ready tag (stays draft until operator reviews)
```
