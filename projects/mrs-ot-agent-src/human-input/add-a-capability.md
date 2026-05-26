# How to add a new capability

A capability is a small classifier that takes a payload (SEV, post, alert) and returns a structured verdict. Existing examples: `team_lane_scope`, `sev_identification`. This doc tells you how to add one without re-inventing the wiring.

## The shape

| Surface | What you build |
|---|---|
| Module | `src/capabilities/<name>.py` with one public function returning a typed verdict (`@dataclass(frozen=True)`). |
| Config | A new top-level block in `triage_config.yaml` plus a typed model in `src/config_schema.py`. |
| Logging | One `log_decision(...)` call per branch (use the `_logging.py` helper from D103338751). |
| Tests | `tests/test_<name>.py` with positive + negative + edge-case branches. |
| Optional CLI | `src/<name>_check.py` if operators need to invoke it directly — pattern after `scope_check.py` (supports `--trace`). |

## Steps

1. **Define the verdict**: a `@dataclass(frozen=True)` class with at minimum `verdict: str`, `signal: Optional[str]`, `rationale: str`.
2. **Write the classifier**: pure function. Read config via `get_config()`. Emit one `log_decision(...)` call before each return.
3. **Add the config block**: append to `triage_config.yaml`. Add a typed model to `src/config_schema.py` and reference it from `OtTriageConfig`.
4. **Add tests**: cover the happy path, the negative path, and any explicit edge cases. Use the existing tests in `test_team_lane_scope.py` as a template.
5. **Optional CLI**: if direct invocation is useful, add `src/<name>_check.py`. Take `--trace` and `--trace-out` flags so operators can replay end-to-end.
6. **Update SKILL.md**: one row in the Reference Files table pointing at the new module.
7. **Submit**. The three submission fields required by `.llms/rules/ot-agent-conventions.md` § Diff Submission are: reviewer `#mrs-ot-reliability`, tag `publish_when_ready`, task `T259215482`. Aim for `<=150 lines`, and keep `.py` and `.yaml` in separate diffs to maximize RADAR auto-stamp eligibility. Other tags (such as those used for routing across broader streams) are not part of the conventions and stay optional.

## Conventions to mirror

| Convention | Where |
|---|---|
| Logging | `src/capabilities/_logging.py` (D103338751) |
| Config schema | `src/config_schema.py` (D103340523) |
| Verdict dataclass shape | `team_lane_scope.ScopeVerdict` (current canonical) |
| Test fixtures | `tests/test_team_lane_scope.py` |
| Skill convention rule | `.llms/rules/ot-agent-conventions.md` |

## Anti-patterns

- Module-level `frozenset({...})` constants for domain values. Put them in yaml + the typed config schema. (S657101 was caused by hardcoded frozenset drift.)
- Silent failure paths. Every classifier branch must emit a `log_decision(...)`.
- `dict.get("k", default)` when `k` may be JSON `null` — `.get(default=...)` only fires on missing keys, not null values. Use an explicit `is None` check: `v = d.get("k"); v = v if v is not None else default` (note the second `v =` — without it the ternary is a no-op and `v` stays `None`). The shorter `dict.get("k") or default` looks tempting, but silently replaces any falsy value (`0`, `""`, `False`, `[]`) — a config value that can legitimately be `0` or empty will hit the default branch by accident.
- Reviewing your diff with individuals on the reviewer list when the goal is RADAR auto-stamp. Group-only.

## Reviewer expectations

Submit as `--draft --publish-when-ready` with `#mrs-ot-reliability` and the relevant adjacent group. The reviewer expects:

- New file is under `src/capabilities/` or `src/<name>_check.py`.
- Tests in `tests/test_<name>.py`.
- Config block in `triage_config.yaml` lands as a separate diff if mixed with `.py`.
- One `log_decision(...)` per branch.
- No new external deps unless you've cleared it with the team.
