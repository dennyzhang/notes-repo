# iter6 workflow plan — fix for iter5 stall

**Root cause of iter5 stall:** Workflow's triage agents timed out (6 × 180s = 18min). Each agent needed to Read 3 large knowledge files (SKILL.md 15KB + KP.md 80KB + TD.md 48KB = 144KB) plus do structured reasoning. Under the daemon execution context, these long-running multi-tool agents stalled.

**Fix strategy for iter6:**

## 1. Batch triage (4 agents → instead of 18)

Instead of 1 agent per case × 18 cases, use:
- 1 agent for all 4 Dec-baseline cases
- 1 agent for all 4 Dec-treatment cases  
- 1 agent for all 5 Own-baseline cases
- 1 agent for all 5 Own-treatment cases

Each batch-triage agent reads the knowledge files ONCE and produces an array of diagnoses. Reduces total knowledge-file reads from 18× to 4×.

Schema: `{ diagnoses: [{ id, root_cause, p_row, owner, verdict, confidence }] }`

## 2. pipeline() for grading instead of parallel()

Grade results sequentially through pipeline() to avoid triggering the harness agent-slot exhaustion that caused stalls.

## 3. Targeted knowledge: read only the sections relevant to the targeted cases

Instead of reading all 80KB of known-patterns.md, have one "context prep" agent extract only the P-rows referenced in the targeted cases' ground truth (P44, P50, P56 etc.) plus the R-rules from triage-discipline.md. This reduces per-triage-agent context by 70-80%.

## 4. Retry with Agent-tool fan-out if Workflow stalls again

If the batch workflow also stalls:
- Use Agent tool (not Workflow) for each of the 4 batch-triage agents sequentially
- Each Agent call handles one arm (baseline/treatment × Dec/Own)
- 4 sequential Agent calls instead of one Workflow with 4 parallel agents

## Key rule designs for iter6

### Decisiveness v5 (target same 4 cases: S607776, S657690, S667567, ALERT-1533487445064477)

Fixes from v4: (1) NOTE clause now says "regardless of its class label" not "without exception"; (2) added PAGE+confirmed-model-identity+no-MAST-job fallback via meta ai.model describe

### OwnerRouting v6 (target same 5 cases: ALERT-1201406268614142, ALERT-1533487445064477, A1703030847735006, ALERT-1427819186056622, S665454)

Fixes from v5: (1) dual-field try (model_owner_unixname then model_owner); (2) STUS REAL_OT_FAILURE uses model name as --model-id directly; (3) mrs_ig_retrieval_oncall hard fallback for STUS empty-owner

## Reference: iter6 targeted case ground truths

| id | type | gt_owner | gt_verdict_class | dec_target | own_target |
|---|---|---|---|---|---|
| S607776 | sev | Zichang Feng | mitigated (revert+gradient clip) | ✓ | |
| S657690 | sev | lupaul (Paul Lu) | MITIGATED_WITH_FOLLOWUP | ✓ | |
| S667567 | sev | fengzhang1 | mitigated (manual kill+restart) | ✓ | |
| ALERT-1533487445064477 | alert | mingchao (paged) | REAL_OT_FAILURE | ✓ | ✓ |
| ALERT-1201406268614142 | alert | none | NO_ACTION (DETECTOR_BROKEN) | | ✓ |
| A1703030847735006 | alert | yufengma / feed_ecosystem_core_modeling | REAL_OT_FAILURE (P56 Shampoo NaN) | | ✓ |
| ALERT-1427819186056622 | alert | upstream infra owners | UPSTREAM_INFRA | | ✓ |
| S665454 | sev | mlygao | MITIGATED_WITH_FOLLOWUP (CUDACachingAllocator) | | ✓ |
