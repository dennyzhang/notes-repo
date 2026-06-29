# Hedwig Streaming — Flow Control Onboarding

Read and follow the onboarding guide at `fbcode/hedwig/download/docs/runbooks/streaming/flow_control_onboarding.md`. It contains:

- **Section A (Human Runbook):** Step-by-step onboarding with quick checklist
- **Section B (Agent Runbook):** Machine-parseable instructions for creating configerator diffs

## When to Use

Use this reference when the user asks:
- "Is this model onboarded to flow control?"
- "Is there a bug in flow control onboarding?" / "Is flow control configured correctly?"
- "Can you onboard trainer ID X and predictor ID Y to flow control?"
- "Enable flow control for model X"
- "How do I set up flow control?"

## Quick Answers

### Is this model onboarded to flow control?

The onboarding guide's **Step 3b (Verify Onboarding Correctness)** in the flow control runbook (`fbcode/hedwig/download/docs/runbooks/streaming/flow_control_runbook.md`) has 5 grep-based checks to verify onboarding. Run them against:
- `$CONFIGERATOR_ROOT/source/hedwig/download/peer/hedwig_peer_config.mcconf` — check `ADAPTIVE_FLOW_CONTROL_TRAINER_IDS` and `ADAPTIVE_FLOW_CONTROL_PREDICTOR_IDS` lists
- `$CONFIGERATOR_ROOT/source/justknobs/hedwig/streaming.cconf` — check `use_adaptive_flow_control` rules

### Is there a bug in flow control onboarding?

Run the same Step 3b checks — they detect common typos:
- Missing `m` prefix on predictor ID
- `_latest` vs `_slatest` typo in JK regex
- Swapped trainer/predictor IDs
- ID in peer config but not in JK (or vice versa)

### Can you onboard this model to flow control?

Follow the **Agent Runbook (Section B)** in the onboarding guide. Required inputs: `TRAINER_ID` and `PREDICTOR_ID`. The agent creates a configerator diff modifying two files, runs `conf build`, and submits for review. For grafting required diffs, invoke the `hedwig-streaming-diff-graft` skill.

## Reference Diff

[D105972229](https://www.internalfb.com/diff/D105972229) — complete example of enabling flow control for a model.
