```yaml
fix_id: model-id-verification-via-flow-model-type
title: Verify model_id matches SEV title family via flow_model_type before locking in triage
status: 🟡 drafted
identified: 2026-05-20 thread 2wDCp51dUxE
target: team_bot/cron-jobs/ot-sev-monitor.md
section: SEV → model_id resolution
impact: Closes "Opsmate cites wrong model" failure mode (2+ instances today)
cost: ~10-line cron prompt amendment
```

## Gap

Cron took Opsmate's literal text `"...affecting model 2129246926..."` at face value and triaged that model. Actual SEV target was a different model (m2124122280 for S665454 — Threads Retrieval U2M). Two instances today:

1. **S665454 / m2129246926**: Opsmate said model 2129246926 (threads_feed_mtml, ranking team). Actual: m2124122280 (ig_textpost_feed_u2m_retrieval, retrieval team) per gchat AAQAxtHFwMQ.
2. **m877766932 (facebook_reels_vdd_hstu_v0)**: cron correctly identified DETECTOR_BROKEN; I incorrectly mis-attributed owner to yabinzh / mrs_retrieval_u2i (snapshot oncall, not model owner). Right answer: charlesz / minimal_viable_ai.

## Patch

### Before

```
For each SEV with Opsmate root cause text:
  1. Extract model_id from Opsmate text
  2. Triage that model_id
```

### After

```
MODEL_ID VERIFICATION BEFORE TRIAGE LOCK-IN:

  1. Extract candidate model_id from any of:
     - Opsmate root cause text
     - SEV title regex (model_<number>, m<number>, model id <number>)
     - SEV's mentioned_diffs commit messages
     - SEV gchat space first message (parse mvai-training-online-<id> URLs)

  2. For each candidate model_id, verify via:
     meta ai.mast-job describe --name=mvai-training-online-<id>

     Check:
     - flow_model_type matches SEV title's model-family signal
       (e.g., SEV title says "Threads Retrieval U2M" → flow_model_type
        should contain "u2m_retrieval"; if it contains "threads_feed_mtml"
        → MISMATCH, candidate is wrong)
     - flow_entitlement matches PG signal in SEV title
     - oncall matches SEV's modeling oncall

  3. If MISMATCH between Opsmate's model_id and SEV title:
     - Opsmate's reference is wrong (this happens; do not trust blindly)
     - Fall back to title-driven model search:
       * Parse SEV title for model_type tokens
       * Query model registry / SLICK for models matching the type
       * Cross-check via SEV gchat space mvai-training-online URLs
     - Re-run verification with the corrected candidate

  4. ALSO derive ROLES:
     - SEV title contains "holdout" → role: holdout
     - SEV title contains "baseline" → role: baseline
     - flow_entitlement contains "retrieval" → role: trainer/retrieval
     - entrypoint contains "st_update_service" → role: stus (R14)

  5. CITE in verdict which evidence anchored the model_id choice
     (so auditor can flag mis-attribution post-hoc):
     ```
     [VERIFIED: model X via flow_model_type=Y matches SEV title;
      Opsmate cited model Z — falsified by flow_model_type mismatch]
     ```

  6. ALSO distinguish model-owner from snapshot-instance-oncall:
     - flow_entitlement / flow_root_workflow_tags → modeling oncall + owner
     - meta ai.model.instance list .oncall field → snapshot publishing oncall
     - These can be different teams. Cite the right one based on context.
     - For PAGE recommendation: modeling oncall is the actionable owner.
     - For snapshot-publish-path issues: snapshot oncall is the relevant team.
```

## Triggering evidence

- S665454 m2129246926 vs m2124122280 — operator caught this 2026-05-20 in thread 2wDCp51dUxE
- m877766932 — operator caught yabinzh vs charlesz mismatch via same session

## Validation

- [ ] Audit 20 SEV triages after landing; 100% should have model_id verification citation
- [ ] No instances of Opsmate model_id used without cross-check
- [ ] Owner attribution matches snapshot-vs-modeling distinction

## Related

- `04-fs-cadence-check-not-zero-in-last-n.md`
- `IMPROVEMENT-PROPOSALS.md` Proposal F evidence-completeness checklist
