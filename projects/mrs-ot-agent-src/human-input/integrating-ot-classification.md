# Integrating OT classification

## Public API

| Symbol | Purpose | Returns |
|---|---|---|
| `is_in_mrs_org_scope(sev: dict)` | Scope check for MRS org boundaries | `ScopeVerdict` (`in_scope`, `signal`, `rationale`) |
| `classify(sev: dict, ot_ics: frozenset[str])` | OT-keyword + signal lane match | `CandidateSEV \| None` (`tier`, `rationale`, `sev_id`, ...) |

Import:

```python
from pe_mrs_ml.mrs_ot_agent import (
    CandidateSEV,
    classify,
    is_in_mrs_org_scope,
    ScopeVerdict,
)
```

Everything else under `src/` is internal — names and shapes may change.

## Recipes

### Cron prompt / WIB bot (Python)

Wire the routing decision through the public API instead of duplicating regex/keyword lists:

```python
from pe_mrs_ml.mrs_ot_agent import classify, is_in_mrs_org_scope

for sev in fetch_in_progress_sevs():
    if not is_in_mrs_org_scope(sev).in_scope:
        continue
    match = classify(sev, ot_ics=ot_ic_set)
    if match is not None:
        route_to_ot_lane(match)
```

### Investigation skill

For interactive replay use `scope_check.py --trace` (D103339828) — it prints
each capability decision with rationale.

## Stability contract

- The 4 symbols above are stable. Breaking changes ship as deprecation cycles >=1 quarter.
- Internal `src/capabilities/*` may change without notice.
- Config drift produces friendly errors at startup via `validate_config_at_startup()` (D103340523).
