```yaml
fix_id: parse-all-jobs-from-sev-chat
title: SEV escalation often lists multiple affected jobs — parse all from first chat message
status: 🟡 drafted
identified: 2026-05-20 thread MQwOLaC3jLc (S665454 escalation)
target: team_bot/cron-jobs/ot-sev-monitor.md
section: SEV → affected models extraction
impact: Triages the FULL incident scope instead of one model
cost: ~10-line cron prompt amendment
```

## Gap

For S665454, Luya Gao's escalation listed THREE affected jobs:
- mvai-training-online-2124122280
- mvai-training-online-2124793203
- mvai-training-online-2124428748

Cron took Opsmate's single-model citation and triaged only one (and got it wrong — m2129246926). Should have parsed all three jobs from the SEV chat first message and triaged them as a cluster.

## Patch

```
SEV CHAT — PARSE ALL AFFECTED JOBS:

  1. Pull SEV chat via: meta sevmanager.chat list --sev=<num>
     (NB: if chat is inaccessible to bot — see 14-sev-chat-via-meta-cli.md)

  2. In the chat's FIRST message (typically operator's escalation):
     Regex-scan for: mvai-training-online-<digits>

  3. ALSO regex-scan for: model_<digits> | m<digits> | model id <digits>

  4. ALSO regex-scan for: mlhub/pipelines/runs/mast/mvai-training-online-<digits>

  5. Collect all distinct model_ids → treat as CLUSTER, not single model

  6. For each model_id:
     - Verify via flow_model_type vs SEV title (per 05-model-id-verification.md)
     - Compute role
     - Triage with shared root cause framing

  7. CITE all model_ids in the verdict:
     "Affected models in S<num>: <id1>, <id2>, <id3>. All triaged with
      shared root cause <R-NNN>. Per-model status:
        - m<id1>: <status>
        - m<id2>: <status>
        - m<id3>: <status>"
```

## Triggering evidence

- 2026-05-20 thread MQwOLaC3jLc — S665454 has 3 affected jobs; cron triaged 1 (wrong one)

## Validation

- [ ] Audit SEV chats with mvai-training-online URLs; bot extracted all of them
- [ ] No instances of single-model triage when chat shows multi-model escalation

## Related

- `05-model-id-verification-via-flow-model-type.md`
- `14-sev-chat-via-meta-cli.md`
