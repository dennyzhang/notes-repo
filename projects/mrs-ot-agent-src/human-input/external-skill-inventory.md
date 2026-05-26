# External Skill Inventory

The OT master agent routes specific failure shapes to sibling skills owned by other teams. Each entry below names the skill, the POC, and when to invoke it from a triage flow. Centralized here so adding a new sibling skill is a single PR — not a denylist update across cron prompts, the WIB bot, and the master agent (the drift that let the S657101 leak happen).

## Skills

| Skill | Owner / POC | Location | Invoke when |
|---|---|---|---|
| MVAI OT reliability investigation | MRS OT (`mrs-ot-reliability`) | `fbsource/fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/investigate-mvai-ot-job-reliability.md` | Input is a specific MAST job name (`mvai-training-online-<ID>`) + any reliability symptom (job failure, example age, stale model, TMS kill, publish failure, running but unhealthy). See SKILL.md § Skill Routing for the full routing table |
| `model-processing` plugin (TGIF) | Kurt Payne (`kurtpayne`) | `fbcode/claude-templates/components/plugins/model-processing/` (install via `agent-market plugin model-processing install`) | Triage matches a publish-side pattern (e.g., P19 / P20) in `known-patterns.md` |
| IP serving-debug agent (POC) | Kian Win Ong (`kianwin`), Hongbo Qin (`hongbo1001`) — RecSys Inference | POC stage, not yet codified — contact `kianwin` | Triage matches a T4 (serving) pattern in `known-patterns.md` — distinct from training-side patterns (T1/T2/T3) owned by MVAI |

## How to register your skill

To add a new external skill that the OT master agent should route to:

1. Add a row to the **Skills** table above. Required fields: skill name, owner unixname, code location (or `POC stage, contact <unixname>`), invoke-when description.
2. If the skill is fbcode-resident, link the `SKILL.md` path or the install command so callers can reach it directly.
3. If the skill is plugin-only (claude-templates plugin tree), include the install command (`agent-market plugin <name> install`).
4. Submit as a draft diff with `#mrs-ot-reliability` as reviewer; the OT master agent maintainers will land it.
5. Keep the `Invoke when` cell as a *pattern reference* (e.g., "Triage matches P19 / P20 / a T4 pattern in `known-patterns.md`"). Do NOT inline error keywords, MAST job prefixes, or alert tags here — those belong in the canonical pattern DB (`known-patterns.md`) and triage config (`triage_config.yaml`). This keeps a single source of truth for routing signals and avoids the drift this file was built to prevent.

## Why a centralized inventory

First-line problem routing was previously implemented per-component: cron prompts, the WIB bot, and the master agent each carried their own list. That denylist drift is what let the S657101 Ads-SEV-in-MRS-lane leak happen on 2026-04-30 — one component's list was tighter than another's.

One source of truth means:

- **One PR adds a skill** — no synchronized edits across N components.
- **Per-team skill ownership stays with the owning team.** The inventory only records the routing edge, not the skill's internals.
- **Failure shapes map to owners explicitly.** When triage matches a pattern in this table, the master agent has a named POC to escalate to instead of falling back to generic oncall.

## See Also

- `SKILL.md` — top-level OT master agent skill (Decision Matrix and Pipeline Architecture)
- `references/ownership.md` — internal component ownership and oncall contacts
- `known-patterns.md` — pattern DB driving keyword-based routing
