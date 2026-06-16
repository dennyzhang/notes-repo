---
name: NRWO9u0tExo
human_involved: false
thread_id: NRWO9u0tExo
space: spaces/AAQAVOjYc80
msg_count: 3
date_range: 2026-05-09T04:06Z — 2026-05-09T04:07Z
---

# Thread Summary: S661149 Postmortem — mvai_publish_pipeline ImportError (auto)

_Source: spaces/AAQAVOjYc80 thread `NRWO9u0tExo` · 3 messages · 2026-05-09T04:06Z–2026-05-09T04:07Z_
_Summarized: 2026-06-02 16:43 PT · last-msg-time: 2026-05-09T04:07Z_

## What was discussed

Automated postmortem digest for L4 S661149 (closed). A cron or bot posted the postmortem and a pattern proposal. Validator confirmed root cause and remediation. This is a clean auto-triage thread — no operator corrections.

## Key decisions made

- Root cause (sourced from SEV overview): D101665186 renamed `get_query_union_from_serialized_dataset_ml_data_config` but left 2 callers in `data_preproc/services/ml_data_component` un-updated → ImportError at runtime, blocked mvai/light_cli since R37834
- Remediation: Revert of D101665186 landed ~20:30 PDT May 7; closed May 8 11:22 PDT (14h 49m total)
- P39 pattern proposal: "Diff renames function, callers in sibling module un-updated → ImportError blocks release pipeline" — proposed, not yet landed in known_patterns.md

## Files / artifacts touched

| path | what changed |
|---|---|
| N/A | pattern proposal P39 drafted in thread; no file confirmed written |

## Cluster / pattern references

- Pattern proposal P39: function-rename with un-updated sibling callers → ImportError at release CI — falsifier: grep the ImportError symbol across repo; if symbol still exists, different failure

## Followup items (not yet done)

1. Land P39 into known_patterns.md (proposed in thread, no confirmed land recorded)

## Cross-refs

- SEV: S661149 (L4, closed, owner: trevormathisen)
- Diff: D101665186 (root cause)
- Release: R37834
