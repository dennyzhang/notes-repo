---
name: debugging-model-freshness
description: >-
  Locally reproduce and debug Sigrid Predictor model freshness issues
  (inplace / delta / streaming updates, snapshot transitions). Use when
  testing inplace update behavior, reproducing staleness bugs, or
  validating snapshot transitions on devgpu.
apply_to_user_prompt: >-
  User wants to reproduce or debug model freshness, inplace update,
  or snapshot transition issues locally.
apply_to_regex: 'sigrid/(predictor/(generic_update|recsys_inplace_update)|lib/model/(InplaceModelUpdate|ModelManagerBase))/.*'
---

# Debugging Model Freshness Locally

## Prerequisites

- Devgpu with GPUs, IPR CLI (`ipr --help`), Manifold CLI (`manifold ls`)
- Model entity ID and (optionally) snapshot ID

## Interaction Guidelines

At each step, explain what you are doing and why, then ask for needed input. Gather these upfront:

- **Model entity ID** and **Snapshot ID** (if unknown, query UMM for latest)
- **Repro scenario** — full snapshot transition, streaming, delta update, etc.
- **Binary source** — build from source (specific commit/diff) or fbpkg?

## Workflow

```
- [ ] Step 1: (Optional) Checkout commit / prepare binary
- [ ] Step 2: Download model snapshot via IPR CLI
- [ ] Step 3: Download target snapshot for transition
- [ ] Step 4: Add freshness flags to run_cmd.sh
- [ ] Step 5: Start predictor
- [ ] Step 6: (Optional) Send replayer traffic
- [ ] Step 7: Analyze logs
```

### Step 1: (Optional) Checkout Commit and Prepare Binary

Must happen before Step 2, since `ipr load model` asks about binary source.

**Ask user:** Build from source (specific commit/diff) or use fbpkg?

**Option A — Source build:**
```bash
sl checkout <BASE_COMMIT>
sl graft <DIFF_ID>        # if applying a diagnostic diff
```
Then choose "build from source" in Step 2.

**Option B — fbpkg:**
```bash
ipr load model --model-id <MODEL_ID> --snapshot-id <SNAPSHOT_ID> --fbpkg-version <VERSION>
```

Skip this step if no specific version is needed.

### Step 2: Download Model Snapshot via IPR CLI

```bash
ipr load model --model-id <MODEL_ID> --snapshot-id <SNAPSHOT_ID>
```

Omit `--snapshot-id` to auto-fetch latest from UMM.

**Ask user:** IPR CLI may interactively prompt for:
- **Tenant** — which tenant to use if model has multiple
- **Source vs fbpkg** — choose source if Step 1 was done
- **GPU type** — AMD/NVIDIA based on devgpu hardware

**Outputs** (in `~/models_and_metadata/run_configs/cmd/`):
- `run_cmd_<MODEL_ID>_<SNAPSHOT_ID>.sh` — launch script
- `ipr_repro_<MODEL_ID>_<SNAPSHOT_ID>.sh` — reproducible command

Note the `sigrid_force_model_dir` path (typically `~/models_and_metadata/<MODEL_ID>_<SNAPSHOT_ID>/`).

### Step 3: Download Target Snapshot for Transition

Inplace update testing needs a **second (newer) snapshot** to transition into.

**Ask user:** Do they have a target snapshot ID, or should you query UMM?

```bash
buck2 run fbcode//ipnext/.claude/skills/query-umm/resources:query_umm -- \
  --model-id <MODEL_ID> --last-n 10
```

Pick a snapshot **newer** than Step 2's, then download:

```bash
drhdfscli resolve fblearner://user/facebook/fblearner/predictor/<MODEL_ID>/<TARGET_SNAPSHOT_ID>

manifold ls ads_storage_fblearner/tree/user/facebook/fblearner/predictor/<MODEL_ID>/<TARGET_SNAPSHOT_ID>/

cd ~/models_and_metadata/<MODEL_ID>_<SNAPSHOT_ID>

manifold get --parallel \
  ads_storage_fblearner/tree/user/facebook/fblearner/predictor/<MODEL_ID>/<TARGET_SNAPSHOT_ID>/<MODEL_ID>_<TARGET_SNAPSHOT_ID>.predictor \
  <MODEL_ID>_<TARGET_SNAPSHOT_ID>/<MODEL_ID>_<TARGET_SNAPSHOT_ID>.predictor

manifold get --parallel \
  ads_storage_fblearner/tree/user/facebook/fblearner/predictor/<MODEL_ID>/<TARGET_SNAPSHOT_ID>/<MODEL_ID>_<TARGET_SNAPSHOT_ID>.predictor.local \
  <MODEL_ID>_<TARGET_SNAPSHOT_ID>/<MODEL_ID>_<TARGET_SNAPSHOT_ID>.predictor.local
```

Check Manifold listing for additional suffixed files (e.g., `.predictor.score_with_user_embedding`) and download those too. Verify both snapshots exist under `sigrid_force_model_dir`.

### Step 4: Add Freshness Flags to run_cmd.sh

Set `--enable_inplace_snapshot_transition` as master switch, then pick scenario. See [references/inplace-update-flags.md](references/inplace-update-flags.md) for full flag table.

**Ask user:** Confirm which scenario matches their repro goal.

**Single transition (A<->B):**
```bash
--enable_inplace_snapshot_transition \
--inplace_update_test_mode=1 \
--inplace_update_test_full_snapshot_id=<TARGET_SNAPSHOT_ID>
```

**Continuous (while serving):**
```bash
--enable_inplace_snapshot_transition \
--inplace_update_test_mode=2 \
--inplace_update_test_full_snapshot_id=<TARGET_SNAPSHOT_ID>
```

Add `--inplace_update_test_enable_streaming=true` if streaming is involved.

Append log redirection:
```bash
... 2>&1 | tee /tmp/freshness_debug_<MODEL_ID>_<SNAPSHOT_ID>_$(date +%y%m%d_%H%M%S).log
```

### Step 5: Start Predictor

```bash
SKIP_WARMUP=true CUDA_VISIBLE_DEVICES=0,1 \
sh run_cmd_<MODEL_ID>_<SNAPSHOT_ID>.sh
```

Watch for: model load success, inplace update triggers, missing file errors (go back to Step 3), transition completion.

### Step 6: (Optional) Send Replayer Traffic

**Ask user:** Do they have a `.recordio` traffic file? Needed only when bug requires concurrent serving (e.g., ZCH free slot divergence). Skip otherwise.

```bash
manifold get --parallel <TRAFFIC_MANIFOLD_PATH> ./replayer_traffic.recordio

BUILD=1 REQUEST_METHOD=runModelMethod MODEL_ID=<MODEL_ID> SNAPSHOT_ID=<SNAPSHOT_ID> \
REQUEST_FILE_PATH=./replayer_traffic.recordio RUN_LOCALNET_ON_CLIENT=false \
SERVER_PORT=<PORT> \
sh hpc/inference/scripts/gif/vdd/1_card/launch_gpu_replayer.sh 2>&1 | tee /tmp/replayer.log
```

### Step 7: Analyze Logs

**Ask user:** Do they have a specific error pattern or keyword to search for?

- **If user provides a pattern:** Search the log file for that pattern with surrounding context to understand the failure.
- **If no pattern provided:** Start by searching the log for `ERROR`, `FATAL`, `exception`, `abort`, or `crash` keywords to find the first error, then expand context around it.

For each error found:
1. Extract the source file path and line number from the log (e.g., `SomeFile.cpp:123`)
2. Read the corresponding source code at that location
3. Trace the call chain to understand how the error was reached
4. Cross-reference with the test inplace update code path in `sigrid/lib/model/InplaceModelUpdate.cpp` — trace upstream callers and downstream functions to understand how the test flow triggers the error
5. Identify the root cause based on the code path and the state logged around the error

## Troubleshooting

- **IPR CLI fails:** Verify `ipr --help` works. Check model exists: `bunnylol ummmeta <MODEL_ID>`
- **Missing snapshot files:** Re-run Step 3 with correct target snapshot ID
- **No inplace triggered:** Check `--enable_inplace_snapshot_transition` and `--inplace_update_test_mode != 0`
- **Crash during transition:** Try without grafted diff first as baseline

## References

- **[inplace-update-flags.md](references/inplace-update-flags.md)**: Test flag table and common scenarios
- **[IPR CLI Docs](https://www.internalfb.com/wiki/Inference/Inference%3A_Internal/Teams/RecSys_Runtime_Team/IPRCLI_Docs/#1.-Load-Models-(ipr-load))**: Full usage guide. Also: `ipr --help`
