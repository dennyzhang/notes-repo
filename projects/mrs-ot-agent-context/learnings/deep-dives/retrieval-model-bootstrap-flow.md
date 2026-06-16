# Retrieval-Model Bootstrap Flow (OT continuous training)

How an MRS/IG **retrieval** online-training (OT) model comes up — from job launch to
serving — and **which step resolves "where do I resume from."** Step 3 is the
bootstrap-critical resume-state resolution and the site of the 2026-06-13 S675238
checkpoint-churn incident.

Discovered/verified 2026-06-13, thread `Nk_Ui4WFn4U` (model 2137792444 / S675238),
from live v90/v91 MAST stacks + trunk source read. Sibling refs:
[ot-data-pipeline.md](./ot-data-pipeline.md) (step 5 data),
[ot-publish-architectures.md](./ot-publish-architectures.md) (step 6 publish),
[tms-state-matrix.md](./tms-state-matrix.md) (TMS lifecycle),
[restart-mechanism-analysis.md](./restart-mechanism-analysis.md) (relaunch).

## The 7 logical steps

```
[1] Launch        recurring FBLearner flow / fire / OT register-and-run submits the
                  continuous-training MAST job  mvai-training-online-<eid>.  TMS owns
                  its lifecycle. On restart / preemption / MRB-reset the SAME job relaunches.
        ↓
[2] Trainer bringup   train.py:main → local_launcher → run_trainer
                  → IgTrainer → MaasTrainer → RecTrainer.__init__
        ↓
[3] Resolve start state  (JOB RESOLVER — bootstrap-critical, incident site)
                  core/trainer/job_resolver.resolve → ig_retrieval/job_resolver.resolve_impl
                  decides WHICH checkpoint to resume from, querying UMM / model-store for
                  the latest / version -1.
        ↓
[4] Load checkpoint   may_load_checkpoint (mvai_infra/checkpoint) loads the resolved anchor
                  (the full state: dense weights + sparse embeddings + optimizer, ~100s of GB)
                  from Manifold via the model-store.  OT RESUMES here — never cold-starts.
                  (cold-start = fresh init ONLY for a genuinely-new model with zero checkpoints.)
        ↓
[5] Stream + train    reads examples from Scribe (via DPP), updates incrementally (online),
                  periodically WRITES new anchor checkpoints (UMM-created, e.g. v1988…) back
                  to model-store + Manifold.   [data detail → ot-data-pipeline.md]
        ↓
[6] Publish       UMM publishes SNAPSHOTS to the ST/publish entity (retrieval:
                  SPARSE_DELTA / ITEM_EMB_DELTA / FULL_SNAPSHOT) → SilverTorch / STUS serving
                  loads them.  Publish entity ≠ training/root entity.
                  [publish detail → ot-publish-architectures.md]
        ↓
[7] Continuous loop   TMS keeps it alive; the recurring flow relaunches on failure; the
                  resume pointer from step 3 is what lets each restart pick up where it left off.
```

## Components

| Stage | Component(s) |
|---|---|
| Launch / orchestration | recurring flow / fire / OT-register + **TMS** + **MAST** |
| Trainer | IgTrainer → MaasTrainer → RecTrainer |
| Start-state resolution | `job_resolver` + **UMM / model-store** |
| Checkpoint I/O | `mvai_infra/checkpoint` ↔ **Manifold** |
| Data | **Scribe** → **DPP** |
| Publish / serve | **UMM** → ST entity → **SilverTorch / STUS** |

## Key facts (the non-obvious bits)

- **OT resumes, it does not cold-start.** Every restart/preemption/MRB-reset reloads the
  latest valid anchor checkpoint. Cold-start (fresh init) happens *only* for a model with
  zero checkpoints. So "missing checkpoint → create a new one" is the WRONG mental model for
  an existing OT model — the right behavior is "resolve and load the latest valid anchor."
- **Version `-1` = sentinel for "latest anchor."** The resolver converts `-1 → None` and asks
  the model-store for the latest. `get_model_instance_metadata(None)` returns `None` *cleanly*
  (does NOT raise) when the latest/resume pointer is missing — `umm_model_instance_manager.py:1515`.
- **Publish entity ≠ training (root) entity.** Step 6 publishes to a different entity than the
  one being trained; don't conflate the two when tracing a serving-staleness symptom back to training.
- **The resume pointer is the linchpin.** It's what step 7 relies on. If a mitigation (MRB)
  wipes it without re-initializing, step 3 has nothing to resolve to.

## Incident map — S675238 (model 2137792444), the canonical failure at step 3

MRB (Massive Revert and Ban — see below) wiped the model's **resume pointer**. On relaunch:
step 3's `resolve_impl` asked for `-1`/latest → model-store returned record-not-found →
the trainer **churned at bootstrap** instead of falling back to the existing valid **v1987**
anchor (v1986/1985 also valid).

- Older live build (`light_cli:4443`): passed a literal `-1` into the lookup →
  `aiplatform.modelstore.metadata_service.ttypes.ModelStoreDBRecordNotFound: 'Checkpoint 2137792444 : -1 does not exist.'`
- Trunk: already converts `-1 → None` at the resolver, BUT then `assert model_instance is not None` —
  so it hard-AssertionErrors on a missing latest instead of **gracefully falling back** to the
  valid anchor. Real gap remains, just not the line the older stack named.
- `checkpoint.py` restore layer is a **different path** whose C++ pybind re-types record-not-found
  into `UMMValidationException` (conflated with invalid-state) → catching there is dead-code/unsafe.

**Fix (filed):** T275782360 (spec) + D108525530 (`--draft`): resolver falls back to
`get_latest_anchor_checkpoint_metadata(entity_id, valid_only=True)` when the latest lookup
returns None; hard-fail only when there's genuinely no valid anchor. Immediate unblock for a
single model: relaunch loading the valid anchor, or owner re-inits the pointer via MRB.

## MRB (Massive Revert and Ban)

Online-training SEV mitigation: revert + ban corrupted data/checkpoints, stop + restart jobs.
- **Owner:** `ads_online_training` + the `tdmi_massive_sev` oncall own the MRB CLI/workflow.
- **Known weakness (relevant here):** a manual MRB restart can leave models resuming from the
  *latest timestamp* with the resume pointer uninitialized rather than from the *last valid
  checkpoint* — which is exactly what triggers the step-3 churn above. The systemic fix is MRB
  re-init of the pointer; the in-trainer fix (D108525530) makes the resolver resilient to it.

### `Checkpoint <eid> : -1 does not exist` after an MRB reset — exact mechanism + recovery (canonical, verified 2026-06-13 W1350388963722513 / S675238)

**The single fact that explains everything: it FAILS and later SUCCEEDS with the *same*
`--checkpoint-version -1` config (job def unchanged throughout).** Therefore `-1` is NOT a
literal version lookup (there is no version `-1`; if it were literal it would still fail) and
the config is NOT the bug. `-1` means **"resolve latest through the model's PARENT checkpoint
lineage."**

**How `-1`/latest resolves (verified construct):** the model store resolves the resume target
by walking the **parent-checkpoint lineage** — `link_to_parent_checkpoint(parent_ver, child_ver)`
and `parent_model_instances` (lineage walk in `aiplatform/modelstore/umm/util/checkpoint_apis.py:625/725`),
NOT by scanning `max(VALID version)`. The lineage root is a checkpoint carrying the **`Parent`
tag** (distinct from the ubiquitous `is_anchor_checkpoint` tag). An OT model is **seeded** by a
`Parent` anchor from the **recurring (batch) train flow**; the continuous OT job
(`OnlineConfigProvider`) then resumes and stacks deltas on top of that root.

**WHY `-1` FAILED (before):** MRB ("Massive Revert and Ban") *killed & reset* the model
(2026-06-12 SEV0 **S675130** + Ads SEV1 S675138; all-PG stop 08:07 PT, revert/ban of snapshots
from 06:30–09:00; announcement post 28250882924500737). The reset **cleared the active
`Parent`/lineage head**. The previously-VALID children (v1985 04:31, v1986 05:55) still existed
as VALID *records* but **carried no `Parent` tag** → orphaned from any active lineage → not
eligible resume targets. So `-1`→resolve-latest found **no parent anchor** → returned
`ModelStoreDBRecordNotFound`, surfacing the requested `-1`. (This is exactly why removing
`--checkpoint-version -1` from the launch config did NOT help — the missing piece was the
lineage root, not the config value.)

**WHY `-1` WORKS (now):** the model owner re-ran the **recurring-train PARENT flow**
(`jobType: RECURRING_TRAINING`, workflow `minimal_viable_ai.recurring_train.recurring_train`,
key flag **`--metadata flow_tags=parent`**, `TrainerConfigProvider`, over a bounded ts window
e.g. `--start-ts/--end-ts` one hour) → it wrote **v1987 tagged `Parent`** — the *only*
`Parent`-tagged version — **re-establishing the lineage root** the reset had wiped. With a
parent anchor present, `-1`→latest resolves to it; on the OT job's next restart it loaded v1987
and resumed → produced v1988. Config never changed; the **presence of a `Parent` anchor** is
the entire difference.

**RECOVERY RECIPE (owner/oncall — bot is read-only on model-store & MAST state):**
1. **Re-establish the `Parent` anchor** — re-run the model's recurring-train **parent** flow
   (the `flow_tags=parent` batch flow) over a recent ts window. This is the owner-side "reset
   the checkpoint metadata" (NOT a config edit, NOT `bulk-recover` unless checkpoints are
   actually purged). It regenerates the lineage root.
2. **Restart/re-register the OT job** so it re-resolves `-1`→the new parent anchor. (In
   W1350388963722513 the parent anchor appeared at 01:38 but the OT job only resumed ~19:38 —
   so the parent flow alone is necessary but an OT restart/re-register is the second required
   step.)
3. Also check **recurrent training wasn't left `is_enabled=false`** by the MRB (R15 recurring-
   flow check; teammate hit exactly this on post 28250882924500737).

**CONFIRM from ground truth (decisive queries):**
- `meta ai.model list-model-instances --model-id=<eid> --columns=checkpoint_version,state,creation_time`
  → if VALID checkpoints exist at real versions but the job dies on `-1`, the **store is fine**
  → it's the lineage-root/`Parent` problem, NOT data loss.
- `get_last_n_checkpoint_metadata(<eid>)` → inspect `tag_names` for **`Parent`**: which version
  (if any) is the current lineage root. Post-MRB-reset: none → that's the broken state.
- Distinguish from the **PURGED** case (different fix): only if `state=PURGED/INVALID` (TTL 14d
  or banned) use `modelstore-cli bulk-recover --instance <eid>:<ver> --model-stage checkpoint
  --recover-mode manifold_recovery|archival_recovery` (Model Instance Recovery wiki [RjTc];
  manifold ≤7d, archival 7–60d needs `--sev`). bulk-recover only flips INVALID/PURGED→VALID; it
  does NOT re-root a missing `Parent` lineage. (Different symptom again: poisoned DPP reader
  checkpoint → `resume_from_reader_checkpoint: false`, APS 2763010904063228.)

**In-trainer resilience (the bot's lever):** D108525530 (`--draft`) makes the base resolver fall
back to the latest VALID anchor when `-1`/latest resolution returns nothing — so a missing
`Parent` root degrades gracefully (resume from newest valid) instead of churning. That's the
systemic prevention; the owner-side parent re-run is the immediate fix.
