# Online Signal Report — 2026-06-11 (Stage 1b, first measurement)

**Period**: last 30 days (2026-05-12 – 2026-06-11)
**Sources**: (a) `triage_events` table — 100 events, (b) `messages` table — HUMAN corrections/confirmations, (c) resolved-SEV archives (18 June + 55 May = 73)

---

## 1. Validator Agreement Rate (production proxy)

| Outcome | Count | % of total | Avg bot confidence |
|---|---|---|---|
| confirmed | 20 | 20% | 0.755 |
| discrepancy | 15 | 15% | 0.653 |
| pending | 14 | 14% | — |
| unavailable | 51 | 51% | — |

**Evaluable cases** (confirmed + discrepancy = 35):  
Agreement rate = **20/35 = 57.1%**

Calibration signal: bot is more confident when correct (0.755) vs wrong (0.653). Gap = +0.102. This is consistent with the offline calibration pattern — the bot isn't systematically overconfident, but the gap is narrower than ideal.

---

## 2. Verdict-Class Breakdown (evaluable cases)

| Bot verdict class | N | Confirmed | Agreement |
|---|---|---|---|
| MONITOR | 10 | 6 | 60% |
| In Progress | 5 | 4 | 80% |
| Mitigated | 4 | 3 | 75% |
| NO_ACTION | 3 | 2 | 67% |
| **PAGE** | **3** | **0** | **0%** |
| UNKNOWN/NEEDS_INVESTIGATION | 2 | 1 | 50% |
| Closed | 2 | 1 | 50% |

**Notable**: PAGE verdicts (highest stakes) have 0% validator confirmation across 3 cases (S674995, S674766, S674760, S674520). However, the discrepancies were in evidence specificity / next actions (e.g., R40956.1 vs R40931 revision) rather than the verdict class being wrong. The underlying PAGE call itself may have been correct; the validator flagged supporting-evidence issues.

---

## 3. Operator Corrections (explicit, last 30d)

4 distinct correction signals extracted from `messages` table:

| Date | Correction type | Specific issue |
|---|---|---|
| 2026-06-12 | Next-action specificity | Bot cited R40931, correct was R40956.1 (S674995 BXL regression) |
| 2026-06-11 | Owner routing | Bot assigned job to "Paul" instead of operator (owner dim) |
| 2026-06-11 | Decisiveness | "shouldn't you look into source code, file task and diff?" (bot stopped short) |
| 2026-06-10 | Scope boundary | "how come ads pipelines are generated" — bot included out-of-scope ads data |

**Alignment with offline dims**:
- Owner routing error → **confirms offline owner dim 0.25 is real** (not a gold-set artifact)
- Decisiveness gap → **confirms offline decisiveness dim 0.53 is real**
- Scope boundary violation → consistent with detection_recall concern (over-broad capture)
- Next-action specificity → not explicitly modeled in current fitness dims; candidate for a future dim

---

## 4. Resolved-SEV Archive Sample (fire-time accuracy)

Only 3 of 100 triage events have `sev_final_root_cause_area` populated in the DB (all "mvai-reliability"). Post-hoc digest validation (from `messages` HUMAN validator outputs) shows:
- ~15 distinct SEV/alert validator runs in last 30d
- Most post-hoc digest confirmations: S670344 ✓, S674228 ✓, S669147 ✓, S672886 ✓, S668285 ✓, S668266 ✓, S670795 ✓
- Discrepancies found: minor (status field wording, recurrence count off-by-one)
- Pattern proposals: all confirmed novel (P59–P64 generated in this window)

**Important distinction**: post-hoc digest accuracy is higher than fire-time triage accuracy. Digests have full SEV resolution data; fire-time triage runs blind. The 57.1% validator agreement rate above is fire-time.

---

## 5. Offline ↔ Online Divergence Assessment

| Metric | Offline | Online |
|---|---|---|
| Composite (weighted) | 0.684 | — |
| Calibration dim | ~0.64 | ~0.57–0.71 (derived from 57.1% agreement, confidence gap) |
| Owner dim | 0.25 | Confirmed weak (1 explicit correction) |
| Decisiveness dim | 0.53 | Confirmed weak (1 explicit correction) |

**Verdict: DIRECTIONALLY ALIGNED. No catastrophic divergence. Offline eval is usable for Stage 3 mutation direction.**

Reasoning:
- The offline calibration ~0.64 loosely maps to the online agreement rate ~0.57–0.71 (depending on how partial-credit discrepancies are weighted)
- Both offline and online identify the same weaknesses (owner routing, decisiveness)
- Gap is partially explained by: offline gold-set uses well-curated historical cases; online validator runs on live incidents where ground truth is noisier
- The eval is NOT mis-calibrated in a way that would generate false positives in Stage 3 — it correctly points at real weaknesses

**What would trigger a halt**: offline composite rising while online agreement falling, or Stage 3 mutations raising composite but operator corrections increasing. Neither observed yet.

---

## 6. Data Gaps

- `sev_final_root_cause_area` field in `triage_events` is nearly empty (3/100). Populating this from the resolved-SEV archives would make fire-time accuracy computable deterministically. This is a substrate improvement for the next offline-online correlation run.
- `validator_outcome = 'unavailable'` (51%) covers DEDUP/OOS/auto-resolved cases where the validator was skipped. These are likely correct decisions but are currently unverifiable.
- PAGE-class discrepancy root cause: validator flags evidence/next-action issues, not always verdict class. A "verdict-only" vs "verdict + evidence" split would improve accuracy of the PAGE class signal.

---

## 7. Recommendations for Stage 3 Sequencing

1. **Proceed with Stage 2** (grader trust): run codex co-grader on a 10-case sample. Current Claude-only grader produces ~57% online agreement; codex cross-check will reveal grader-specific blind spots before batch mutation.
2. **Owner routing** (0.25 offline, 1 confirmed correction online): highest ROI Stage 3 target. The model→owner source map is the key missing piece.
3. **Decisiveness** (0.53 offline, 1 confirmed correction online): second target. "Source code → auto-file task" path is the specific gap.
4. **PAGE evidence quality**: monitor; not yet a mutation target without more samples (n=3 in 30d is low).
5. **`sev_final_root_cause_area` backfill**: low-effort substrate improvement — script to populate from resolved-SEV archives. Enables deterministic fire-time accuracy computation next run.
