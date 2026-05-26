# SEV Firefighting → Follow-Up Diffs

Cheatsheet for converting SEV findings into landed diffs that prevent
recurrence and accelerate future triage. Complements `sev.md`
(active triage) — this one focuses on **after the immediate fire is
out**: what learnings turn into code.

## When to file a follow-up diff

File a follow-up diff when ANY of these are true after a SEV:

| Trigger | Example | Diff shape |
|---------|---------|------------|
| Hang took >10 min before producing diagnostic signal | 3,600s gloo timeout before useful error | Add per-step heartbeat logging |
| Bare collective without timeout | `dist.broadcast`, `invoke_on_rank_and_broadcast_result` | Add timeout (JK-gated) |
| Symptom error fired N frames downstream from root cause | `gloo recv timeout` in trainer when actual hang is in subprocess | Surface root cause locally + log |
| Same error class appeared in N+1 Workplace posts | Pattern, not one-off | Sweep sibling sites in same module |
| Investigation took >30 min to find which class/path is live | Dual-class file, ambiguous variable name | Add unambiguous log line at entry |
| Scuba/log query needed N+ steps to pinpoint failing phase | Per-phase events not emitted, or no primer | Add per-phase logging + scuba primer |
| Mitigation required `--num-hosts` bump or other workaround | Workaround masks underlying bug | Investigate and fix the bug |

## Anti-patterns that show up repeatedly in OT/MVAI SEVs

| Anti-pattern | Codebase rule | Example SEV |
|---|---|---|
| Bare collective without timeout | `aiplatform/modelstore/.llms/rules/ACR_missing_timeout_on_distributed_ops.md` | S371624, S477286, S654235 |
| Top-level error message points at downstream "check rank N" | (memory: `feedback_logs_carry_root_cause_not_pointer.md`) | TGIF publish, S654235 |
| Dual-class router file (e.g., IEN vs GMPP path branches) | (memory: `feedback_subagent_diff_completeness_checks.md`) | S654235 (weights_processing_utils.py) |
| Silent subprocess init failure (no error log until outer timeout) | — | S654235 (gmpp_concurrent.gmpp_process_wrapper.py) |
| Multi-layer wrapper architecture, fix lands in only one layer | — | D103808649 (outer TGIF UMIA only) |
| Sync scuba write blocking model publish path | `inference_enablement/.llms/rules/ien_logging.md` | (potential — to verify) |
| Env-var leak through `mp.Process(spawn)` (TORCHELASTIC, OMP_NUM_THREADS) | — | S658165 (D103808649) |

## Diff anatomy — required sections

### Title

```
[<area>][<subsystem>] <intent in 1 line>
```

Examples:
- `[OT][model_processing] Add per-step heartbeat in wait_for_gmpp_results to surface 3600s deadlocks within 60s`
- `[OT][st_tgif] Fix TORCHELASTIC_USE_AGENT_STORE leak into delta publisher subprocess`

State **intent**, not what's changing. "Add timeouts to invoke_on_rank_and_broadcast_result" is what; "Bound 3600s GMPP publish hangs to 600s with diagnostic" is intent.

### Summary structure (4 mandatory sections)

```
## Problem
What broke. Link the SEV. Quantify (rate, duration, blast radius).
Quote the literal error message verbatim — no paraphrasing.

## Key finding
Verified from logs/source. Specific file:line refs. Per-rank
diagnosis if applicable. Link the investigation paste.

## Why this happens (root cause)
The MECHANISM. Not "X calls Y which times out" — that's the
symptom. Why does Y NOT have a timeout? Why does Z silently fail?
Trace to the upstream design choice that allows the failure mode.

## Why this fix helps
Concrete evidence:
1. Codebase rule that flags this anti-pattern
2. Past SEV(s) caused by same pattern (cite SEV numbers)
3. Past diff(s) that fixed sibling sites (cite D-numbers, fleet impact)
4. What changes for the failure surface (before: 3600s, after: 60s)
```

### Test plan — 3 mandatory bullets

```
## Test plan
- Unit tests covering new logic
- Repro of the SEV pattern (mocked stuck collective, etc.)
- Paste URL with actual run output (per memory:
  feedback_test_plan_paste_evidence)

Tasks: T<number>
```

## Risk-tier decision tree

For ANY follow-up diff that adds a timeout, fail-fast, or behavior
change to a critical path:

```
                    Have p99 latency data?
                    /                    \
                  NO                      YES
                  |                       |
       Heartbeat-only                  Hard timeout?
       (Option B)                      /            \
       File first.                    NO             YES
       Collect data.            JK-gated timeout    Hard timeout
                                (Option A)          (Option C)
                                Default OFF.        Only after JK
                                Ramp 1%→100%.       has run at 100%
                                                    for ≥2 weeks.
```

**Default: Option B first.** Heartbeat doesn't add a new failure
mode. Collect data, then escalate to A or C with confidence.

## Sibling-site sweep — required for ANY anti-pattern fix

When fixing a bare collective / missing timeout / silent-subprocess
issue, **grep the whole module for sibling instances** before
landing the diff:

```bash
# example: missing timeout sweep
fbgs -e "invoke_on_rank_and_broadcast_result\|broadcast_object_list" \
     -f "<module path>" --limit 100

# example: subprocess sync_and_start sweep (per D103808649)
fbgr "def sync_and_start" -f "fbcode/.*\.py" --limit 100

# example: bare dist collective sweep (per ACR rule)
fbgr "(broadcast|all_gather|wait)\(" -f "<module>/.*\.py" --limit 100
```

Per memory `feedback_subagent_diff_completeness_checks.md`: the
sibling sweep is one of the 4 mandatory completeness checks for
any diff. Skipping it caused 3 cleanup rounds in T266851073.

## Reviewer matrix by subsystem

| Subsystem | Path | Default reviewers |
|-----------|------|-------------------|
| MVAI training core | `fbcode/minimal_viable_ai/` | `mvai-ot`, `pe_mrs_ml` |
| MVAI OT reliability | `fbcode/minimal_viable_ai/core/ranking_common/` | `mvai-ot`, `ajfoiani`, `lupaul` |
| Silvertorch publish glue | `fbcode/dper_lib/silvertorch/` | `silvertorch`, `home_ml_platform` (Lei Chen) |
| TGIF publish UMIA | `fbcode/dper_lib/silvertorch/core/experimental/st_tgif/` | `tgif`, `silvertorch`, `dkotfis` |
| GMPP concurrent | `fbcode/aiplatform/modelstore/model_generation/flow/gmpp_concurrent/` | `model_processing` (Nilesh) |
| IEN model processing | `fbcode/inference_enablement/model_processing/` | `model_processing` (Nilesh) |
| PyTorch FB infra (collectives) | `fbcode/caffe2/torch/fb/hpc/` | PyTorch FB infra |

For cross-team diffs (changes file owned by another team's path):
add `model_processing` / `home_ml_platform` / etc. as **blocking**
reviewers, not auto. Always include the SEV-driving person
(`dkotfis` for S654235) for context.

## Common SEV symptoms → likely root cause

| Symptom in SEV thread | Likely cause | Investigation entry point |
|---|---|---|
| `invoke_on_rank_and_broadcast_result failed` | Bare collective deadlock somewhere on `ext_pg`. Real hang is in the COLLECTIVE, not where the error surfaces. | Find which rank logged what last; the silent gap is the hang |
| `gloo recv timeout 3600s` | Some rank parked, others gave up after 3600s | Same as above; check `GMPP_FLOW_PG_TIMEOUT_SECS` |
| `concurrent.futures._base.TimeoutError` | `Future.result(timeout=N)` fired; producer never resolved | Find what should resolve the future |
| `Previous Gmpp process init failed` | Silent subprocess init failure in earlier publish | Look 1+ hour earlier in logs for the actual failure |
| `Publish failed on rank: [X], please check log on rank Y` | Symptom on rank X is a propagated error from rank Y. Always read rank Y's logs. | Pull task-id corresponding to rank Y |
| `[PLATFORM_ERROR][MODEL_PROCESSING]` prefix | model_processing oncall (Nilesh) | Page model_processing; pull `dai_modelstore` Scuba |

## Verification checklist before submitting follow-up diff

- [ ] Verified that proposed code change actually compiles (function signature accepts the proposed param, etc.)
- [ ] Grep-verified every file:line ref in the summary
  (per memory: `feedback_verify_line_refs_in_pastes.md`)
- [ ] Quoted the SEV's literal error message verbatim
  (per memory: `feedback_verbatim_logs_in_drafts.md`)
- [ ] Ran sibling-site sweep
  (per memory: `feedback_subagent_diff_completeness_checks.md`)
- [ ] Test plan includes paste URL with real output
  (per memory: `feedback_test_plan_paste_evidence.md`)
- [ ] `Tasks: T<number>` line present
- [ ] If file is in another team's path, blocking reviewer is added
- [ ] If introducing timeout / fail-fast, JK-gated by default
- [ ] If introducing logging, follows existing
  `@log_component_event_with_error_handling` pattern (for IEN)
  or matching pattern in target subsystem
- [ ] `arc lint -a` clean, `arc pyre check-changed-targets` clean
- [ ] `jf submit --draft` (NEVER without `--draft`)

## Worked example — S654235

| Phase | Artifact |
|-------|---------|
| SEV thread | https://chat.google.com/app/chat/AAQA0RqQaWE/topic/wzXM-Amz8pQ |
| Investigation paste | P2313252859 (4-layer code chain, per-rank stuck location) |
| Brief from SEV PM | P2313129757 (Jiahao's summary) |
| Follow-up task | T270146610 (this cheatsheet's parent task) |
| Cross-reference fix | D103808649 (sibling fix for outer TGIF UMIA wrapper) |
| Codebase rule cited | `aiplatform/modelstore/.llms/rules/ACR_missing_timeout_on_distributed_ops.md` |
| Past SEVs cited | S371624, S477286, S658165 |

## What this cheatsheet REPLACES from raw memory

If you find a recurring rule landing in `memory/feedback_*.md`,
promote it here as a numbered rule. Memory is for in-flight
preferences; this cheatsheet is for institutional patterns. The
following memory entries informed this file:

- `feedback_logs_carry_root_cause_not_pointer.md`
- `feedback_subagent_diff_completeness_checks.md`
- `feedback_verify_line_refs_in_pastes.md`
- `feedback_verbatim_logs_in_drafts.md`
- `feedback_test_plan_paste_evidence.md`
- `feedback_link_supporting_evidence.md`
- `feedback_diff_summary_style.md`
- `feedback_run_presubmit_gate_on_own_diffs.md`
- `feedback_pull_wrapped_exception_first.md`
- `feedback_diff_review_breadth_depth.md`
