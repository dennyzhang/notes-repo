# Thread Summary: Thin cron triage → anti-laziness structural fix, proof-of-work gates confidence

_Source: spaces/AAQAVOjYc80 thread `EOXLCWrOWZM` · 32 messages · 2026-06-04T21:49–22:40Z_
_Summarized: 2026-06-04 22:43 PT · last-msg-time: 2026-06-04T22:40:17Z_
human_involved: true

## What was discussed

Operator flagged that `ot-post-monitor` cron triage of `mvai-training-online-2121486280` (Threads ESR restart-loop) was thin — pattern-matched off post text, never traced code. Operator showed that the same prompt run interactively traced `--delta-publish-config-fqn` → `ESR_OT_DELTA_UPDATE_PUBLISH_CONFIG` → `ESR_WEIGHT_DELTA_PUBLISH` in `delta_publish_configs.py`, found the hardcoded `skip_embedding_table_names` missing 3 RES tables, and produced a one-line fix. Operator also flagged the triage output declared no loaded skills, making it impossible to audit for missed lookups. Operator challenged bot to think harder about structural anti-laziness, not just "try harder" prose.

## Key decisions made

- **🧠 Context: line is now mandatory** at the end of every triage (cron + interactive): lists skills/context loaded (✓/✗) and per-symptom-class expected lookups, so auditors can distinguish a thin triage from a missed lookup. Encoded in CLAUDE.md + `triage-discipline.md` (2026-06-04T22:03–22:04Z).
- **New mandatory step 2-d in `triage-discipline.md`**: for config/code/checkpoint-rooted symptoms or when reporter links a paste/config/diff → dispatch the **deep-triage subagent** (not trace inline) to read every linked artifact verbatim, resolve launch FQNs into fbcode source, compare sibling configs. Wired via Agent tool. (2026-06-04T22:35–22:37Z).
- **Proof-of-work gates confidence**: verdict confidence and PAGE rights must be earned by the evidence artifact the symptom class requires (`path:line` source quote for code-rooted; verbatim MAST error for any PAGE). Without the artifact, confidence capped ≤0.5, verdict downgrades to MONITOR + "needs deeper investigation." High pattern-match + no artifact = MONITOR, never confident PAGE. Validator is now a laziness-detector that rejects shallow output. (2026-06-04T22:38–22:40Z).
- Operator corrections: "why you wait" / "why ask" at 2026-06-04T22:35:09Z → P-001 (act don't ask) + anti-laziness structural fix, not prose.

## Files / artifacts touched

| path | what changed |
|---|---|
| `~/notes/.../CLAUDE.md` | "Triage Transparency" rule: 🧠 Context: line HARD; symptom→expected-lookup map; deep-triage subagent pointer in § Triage Depth |
| `~/notes/.../human-input/triage-discipline.md` | 🧠 Context: line as mandatory last section; step 2-d mandatory code-trace via deep-triage subagent; anti-laziness § proof-of-work-gates-confidence |
| `~/notes/.../team_bot/references/deep-triage-subagent-prompt.md` | NEW — 81-line subagent prompt for code/config-rooted triage: reads linked artifacts, resolves FQNs into fbcode, compares siblings, returns ROOT CAUSE + exact fix + 🧠 Context |
| memory | `anti-laziness-proof-of-work.md` saved |

## Cluster / pattern references

_(no cluster ID — this is an agent-workflow improvement thread, not an OT incident)_

## Followup items (not yet done)

1. Staged in notes — lives at next notes→sqlite sync + daemon restart.
2. Validator now detects shallow triage; cross-model codex adversarial pass still in pilot for code/diff-bearing triages.

## Cross-refs

- Post discussed: Xiao Zang's `mvai-training-online-2121486280` WP post (Threads ESR restart-loop, attempt 13)
- Fix for that post: `delta_publish_configs.py` `ESR_WEIGHT_DELTA_PUBLISH.skip_embedding_table_names` missing `{media_embedding_cache, always_on_media_id, always_on_author_id}`
- Related threads: `rREZuzVSOD8` (same-session crisp WP report request)
