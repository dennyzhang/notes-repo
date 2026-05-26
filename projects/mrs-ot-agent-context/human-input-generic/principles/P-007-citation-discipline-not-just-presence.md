# P-007: Doing the work isn't enough — citing it is what makes the work compound

**Statement:** When a triage applies a known cluster (CL-NNN) or pattern (P-row), the citation must appear literally in the output (`[matches CL-NNN]`, `Apply P<NN>: <mitigation>`). Doing the matching without citing it loses accumulation: cluster evidence doesn't grow, parsers can't link, operator sees novel-looking triages on known recurring patterns.

**Discovered:** 2026-05-17 thread `suPsRC2fGdc` (operator quoted earlier R20/R21 work: "I don't see you have addressed my concerns")

**Why it matters:**
- Cluster registries (failure-patterns.md) grow via citation. Uncited matches = silent drift; cluster cadence understated.
- Recurring patterns get re-derived from scratch each time. Wasted reasoning, slower triage.
- Downstream parsers (knowledge-curation, postmortem-validator, archive INDEX) link via citation. No citation → no link → no aggregation.
- Operator skim assumes verdict reflects catalog; missing citations make them re-verify manually.

**Applies to:** generalizable-to-any-agent-system (any agent maintaining a knowledge base + applying it during inference)

**Current applications:**
- `ot-alert-monitor.md` Pre-publish CONTENT lint: enforces `[VERIFIED: model_<ID> prior_incidents=...]`, `[VERIFIED: family=<model_type>]`, CL-NNN, `Apply P<NN>` citations
- `ot-sev-monitor.md` same
- `ot-post-monitor.md` same (condensed)
- `ot-prompt-change-validator.md` subagent checklist: "all MANDATORY citations are present"

**Anti-patterns it prevents:**
- 2026-05-17 09:25 PT triage on model 878858380 (akCTORdwUK4): bot correctly identified Shampoo NaN cascade mechanism but never cited CL-017 or P56 despite both in catalog. Operator caught the omission immediately.
- 2026-05-17 morning ot-knowledge-curation run: drafted mega-learnings without citing existing CL-NNN, so failure-patterns.md evidence count didn't auto-update.

**Why citation discipline > structural lint alone**

Structural lint (section order, regex format) catches presence-of-section. Content lint catches required-strings-within-section. CITATION discipline catches semantic correctness:

| Lint level | Catches | Misses |
|---|---|---|
| Structural | Missing `*Evidence*` header | Empty Evidence section |
| Content (presence) | `[VERIFIED:]` marker exists | Wrong VERIFIED data |
| Citation discipline | CL-NNN cited when symptom matches | (operator-level review) |

Three layers; each catches what the previous misses.

**Canonical citation mappings**

When triaging a symptom matching:

| Symptom | Required citation |
|---|---|
| NaN at training step | `[matches CL-017]` + `Apply P56: revert to N-2 + ban` |
| Snapshot stuck CREATING | `[matches CL-001]` + R17 invocation |
| Downstream-infra cascade | `[matches CL-003]` + check upstream-infra SEVs |
| Training-age spike | `[matches CL-013]` |
| NCCL timeout | `[matches CL-014]` |
| AGG alert | `[matches CL-018]` + R22 expansion |
| FULL_SNAPSHOT post-FS pause | `Apply P57: wait` |
| Scribe-read-proxy lag + ZippyDB SEV | `Apply P58: route to infra` |
| Etc. (see failure-patterns.md + known_patterns.md for full mapping) |

**Related principles:** P-008 (history repeats — citation IS the mechanism by which history repeats becomes operationally useful), P-011 (spec vs lint), P-009 (validator coverage)
