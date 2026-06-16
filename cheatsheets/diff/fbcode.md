# Fbcode Diff Cheatsheet

<!-- Last updated: 2026-06-06 -->

Fbcode-specific rules for diffs in the fbsource repo. **Read `cheatsheets/diff/common.md` first** for shared Sapling/JF patterns, submit workflows, gotchas, reviewer discovery, and test plan discovery.

## Creating a New Diff

Always create new diffs from the latest `fbcode/stable` tag — not from a draft commit:

```bash
sl pull
sl goto fbcode/stable
# make changes, then commit
```

This ensures diffs are independent and avoids accidental stacking.

## Linter Side-Effect Rule

The Edit/Write tool hooks run linters that can silently modify unrelated files in the working directory (e.g., BUCK auto-updates, test validation scripts). These get folded into the next `sl amend` and create unintended diff content or duplicate diffs.

**After every Edit/Write call:**
```bash
sl status                   # check for unexpected modifications
sl revert <unintended>      # revert linter side-effects
# then amend
```

**For multiple independent diffs:** Use ds1 for one diff and ds3 for the other to avoid working-copy collisions entirely.

## Pre-Submit Checklist

Before `jf submit --draft`, always run:

```bash
arc lint -a                        # auto-apply patches incl. AUTODEPS2 (timeout: 300000)
sl status                          # if BUCK was modified, autodeps2 fixed it — sl amend before submit
arc pyre check-changed-targets     # type check only changed targets (timeout: 300000)
buck2 test <test_target>           # run relevant tests
```

**Always use `arc lint -a`, never bare `arc lint`.** Bare `arc lint` only reports AUTODEPS2 issues without applying the fix — diffs submit red. With `-a`, autodeps2 patches inline; re-amend the BUCK changes before submit. Both `arc lint` and `arc pyre` must pass — hook-enforced. Use `check-changed-targets` (faster than bare `arc pyre`). Always submit as `--draft` first (CLAUDE.md rule).

### Running buck2 / arc under an agent (tool-timeout trap)
`buck2 build`/`buck2 test` first build is routinely 5–15 min, but the agent's Bash tool default timeout is **120s** (kills the command → exit **143**). Do NOT run buck in the foreground and watch it die repeatedly. Either:
```bash
# (a) background + poll (preferred for long buck)
nohup buck2 test //path:target -- --regex '<filter>' > /tmp/t.log 2>&1 &
# then poll with an explicit short tool timeout: pgrep -f target; tail /tmp/t.log
# (b) or set the Bash tool's own timeout high (max 600000ms) for arc lint -a / arc pyre
```
Same trap applies to `arc lint -a` (set timeout 300000). Trust `arc lint -a` autodeps for new-import BUCK deps — don't hand-spelunk target names (e.g. `*-python-types`); edit import → lint → verify the dep landed via `sl status`.

### Finding Test Targets
```bash
# Find test files for your changed file
fbgs "test_<filename>" --limit 10
# Or search by directory pattern
buck2 targets //path/to/tests/: | grep test
```

### Make the Script Importable So It CAN Have a Test

A `python_binary` with `srcs=[...]` + `main_module` is **not importable** — no test target can `import` it, so it ships with zero unit coverage no matter how much logic it holds. "Why does this giant file have no unit test?" is almost always this. If a script is non-trivial, structure it as **library + thin binary + unittest** (mirror `get_mrs_tier1_models` / `get_ot_model_list` in `mvai-ot/BUCK`):

```python
python_library(
    name = "foo_lib",
    srcs = ["path/foo.py"],
    base_module = "...",
    typing = True,                 # library + unittest get typing=True (pyre-strict)
)
python_binary(
    name = "foo",
    main_module = "....path.foo",
    deps = [":foo_lib"],           # binary is a thin wrapper, no srcs
)
python_unittest(
    name = "test_foo",
    srcs = ["path/tests/test_foo.py"],
    base_module = "...",
    typing = True,
    deps = [":foo_lib"],
)
```

Conventions: `typing = True` on the library and unittest targets; lazy-import deps on the **test target only** (§ Lazy Import BUCK Dep Check); no duplicate Starlark keys (§ Duplicate Keys in BUCK/Starlark). If the script already ships an offline `_self_test()`, wrap it in the unittest (`assertEqual(mod._self_test(), 0)`) so CI runs it, then add a focused test per new code path. (Learned 2026-06-05: D107672307 — `check_snapshot_freshness.py`, 1269 lines with a rich `_self_test()`, had no CI test purely because it was a bare `python_binary`; converting to lib+binary+unittest made 4 tests runnable.)

## Pre-Submit Validation

### Caller-Site Completeness Check

Before writing or reviewing a diff that changes a function's behavior (timeout, default value, calling convention), **grep the entire codebase** for all callers — not just the files you already know about. Copy-pasted wrapper functions in sibling modules are the #1 source of missed call sites.

```bash
# Example: find ALL callers of a function across the repo
fbgs "may_wait_for_ongoing_task_done" --limit 50
```

**Lesson learned (D96358986):** Original diff fixed `timeout=None` in `weights_delta_publisher.py` and `tgif_publisher.py` but missed an identical pattern in `delta_only_publisher.py` — a third publisher wrapper with copy-pasted code. A codebase-wide grep would have caught it immediately.

### Lazy Import BUCK Dep Check

Before adding a BUCK dependency, check whether the import is lazy (inside `try/except ImportError`). Lazy imports exist specifically to avoid hard dependencies — adding the dep to the main library target defeats the purpose and can break downstream consumers via transitive blocklist audit failures.

```bash
# Check if the import is lazy
fbgs "try:" <file> --limit 5   # look for try/except around the import
# Check what depends on this target (blast radius)
buck2 cquery "rdeps(//..., //path/to:target)" --output-attribute=name 2>&1 | head -20
```

**Rule:** Lazy import (`try/except ImportError`) → dep goes on the **test target only**. Unconditional import → dep goes on the **main target**.

**Lesson learned (D96502828):** Added `//caffe2:torch` to the main `exceptions` BUCK target for a `try/except ImportError` import. This pulled torch into every downstream consumer of the exceptions library. The correct fix was test-target-only dep.

### Autodeps Side-Effect Check

After running `arc lint -a` or any autodeps tool, always diff the BUCK changes against your intent. Autodeps can:
- Swap `//caffe2:torch` ↔ `//caffe2:_torch` across unrelated targets
- Add deps you didn't intend
- Remove deps that look unused but are needed at runtime

```bash
sl diff --stat   # check for unexpected BUCK changes
# If autodeps changed targets you didn't touch, revert them:
sl revert fbcode/path/to/unrelated/BUCK
```

**Rule:** Only commit BUCK changes for targets you intentionally modified. Autodeps churn in unrelated targets confuses reviewers and can break builds.

**Lesson learned (D96358986):** Autodeps changed `//caffe2:torch` → `//caffe2:_torch` across 5 unrelated BUCK targets. These aren't part of the timeout cap fix but got included in the diff.

### AUTODEPS2 Missing-Dep Check (when adding a new test file)

Adding a new test file with imports that the BUCK doesn't yet declare creates a silent landmine: `arc lint` (no `-a`) reports the AUTODEPS2 error but does NOT fix it; the diff submits, CI fails, and you learn about it from the red signal hours later.

**Always run `arc lint -a` before `jf submit`** — never bare `arc lint`. The `-a` (`--apply-patches`) auto-applies AUTODEPS2 fixes inline, then you re-amend with the corrected BUCK.

```bash
sl status                      # snapshot before
arc lint -a 2>&1 | tail -20    # auto-apply patches
sl status                      # snapshot after — if BUCK appears, autodeps2 fixed it
sl amend                       # fold autodeps2 fix into the diff
jf submit --draft --publish-when-ready
```

**Hook-enforced** (`scripts/quality-gate-precheck.sh`): the precheck runs `arc lint -a` (not bare `arc lint`) and BLOCKS submit if the working-copy state changed during lint — that's the signal AUTODEPS2 had to patch a BUCK. The block message tells you to re-amend.

**When the hook BLOCKS you**, follow this runbook:

1. Read the diff between pre/post lint state (the hook prints the first 20 lines).
2. `sl status` — confirm BUCK files were modified.
3. `sl amend` — fold the autodeps2 patch into the current commit.
4. `jf submit --draft --publish-when-ready` — re-attempt submit; the working-copy state should now be stable.

If the hook blocks twice in a row on the same diff, autodeps2 may be cycling between two valid dep sets. Inspect the BUCK diff manually and pick the correct one.

**Lesson learned (D102408894):** v2 of the diff added a new test file `test_online_training_mgr.py` with `from minimal_viable_ai.utils.online_training_utils.online_training_mgmt import ...`. The BUCK file was amended in the same commit but missing the dep. The pre-submit hook used bare `arc lint` which only *reports* the AUTODEPS2 error — autodeps2 patches are not auto-applied without `-a`. Diff submitted with red CI signal. Fix: switch hook to `arc lint -a` and detect working-copy mutation as a BLOCK condition.

### Pyre-Ignore Dedup Check

After adding `# pyre-ignore` annotations (especially via automated scripts), check for duplicate annotations on the same line:

```bash
# Find duplicate pyre-ignore lines
grep -n "pyre-ignore" <test_file> | sort | uniq -d
# Or check for consecutive pyre-ignore lines
grep -n -A1 "pyre-ignore" <test_file> | grep -B1 "pyre-ignore"
```

**Rule:** Each line of code needs at most one `# pyre-ignore[N]` annotation. Automated scripts that append annotations must check for existing ones first.

**Lesson learned (D96358986):** Automated sed script added `# pyre-ignore[16]` annotations without checking if one already existed, creating doubled-up comments on 8 lines.

### Test Coverage Check

When adding a new helper function, test both the helper AND its integration point:

| Mistake | Example | Fix |
|---------|---------|-----|
| Test helper but not caller | `_get_exit_code_from_exception` tested but `terminate_thread_safe` exit code not verified | Mock the downstream (`exit_w_cleanup`) and verify the full call chain |
| Shallow import mocking | `patch.dict("sys.modules", {"torch": None})` doesn't block `from torch.distributed.elastic...` | Patch every submodule: `{"torch": None, "torch.distributed": None, ...}` |
| Missing edge cases | Exit code 0 from `ChildFailedError` — safety guard clamps to 1 | Test boundary values: 0, -1, large positive |

**Lesson learned (D96502828):** Original tests covered `_get_exit_code_from_exception` in isolation (8 tests) but missed verifying the safety guard in `terminate_thread_safe` that clamps exit code 0 → 1. Also, the import fallback test was ineffective because it only patched the top-level module.

## Pyre: Read the Output, Don't Trust the Hook

**Before every `jf submit` on fbsource, run `arc pyre check-changed-targets` manually and confirm the last line says `No type errors found`.** The pre-submit hook does the same check, but for a long time its grep couldn't see pyre errors (ANSI color codes + pyre error lines don't contain the literal word "error"). The grep was fixed in `scripts/quality-gate-precheck.sh`, but the lesson generalizes: any tool that only surfaces issues via a shell grep is one format change away from silently passing.

### Pyre error patterns that keep biting

| Symptom | Root cause | Fix |
|---|---|---|
| `Returned type 'Unknown \| None' is not assignable to declared return type 'str'` | `some_dict.get(key, fallback)` where the dict is loaded from YAML / thrift / JSON and pyre sees its value type as `Any`. `Any.get(...)` returns `Unknown \| None`, not the fallback type. | Annotate the dict explicitly (`Dict[str, str]`) OR cast the return: `return str(label_map.get(label_key, label_key))`. Don't rely on the fallback value to narrow the return type. |
| `Incompatible parameter type [6]: expected List[Dict[str, object]] but got List[Dict[str, str]]` in tests | Python literal dicts like `{"model_type": "ig_a"}` are inferred as `Dict[str, str]` — pyre doesn't auto-widen to `Dict[str, object]`. | Add an explicit annotation on the test variable: `active: List[Dict[str, object]] = [...]`. |
| `sev_fast_triage_lib-type-checking - unmanaged Failed` but `-library-type-checking Passed` | Buck target type-checking and pyre's "unmanaged" mode run different type-check pathways. A bare `dict` or lowercase `dict[str, str]` may pass one but not the other. | Use `Dict[str, str]` (uppercase, from `typing`) for consistent behavior. Always check BOTH pyre signals in CI, not just the Build-provider one. |

### Pre-submit verification

Always run this block manually before `jf submit` — don't rely on the hook:

```bash
cd ~/fbsource
arc pyre check-changed-targets 2>&1 | tail -15  # expect "No type errors found" as the final colored line
arc lint 2>&1 | tail -5                           # expect "ok No lint issues"
```

If either tool emits anything that looks like a file path followed by `:line:col`, there's an error you need to fix. The "No errors" success string is the ONLY reliable signal.

### F841 (unused local variable)

Pyflakes F841 shows as a Warning, not a blocker, but CI surfaces it in the Devmate review insights. Fix before submit: either use the variable or delete the assignment. Common offenders: intermediate computations left over after a refactor, and unused loop variables (use `_` for those).

## Common Review Comment Patterns

Recurring reviewer feedback on fbcode diffs. Check these before submitting.

### Code Duplication

When two functions share identical structure (iterate files → strip frontmatter → scan lines → check context window), extract a shared helper. Reviewers catch this quickly — DRY violations are the most common structural comment.

**Fix pattern:** Extract the shared loop/scan logic into a helper, pass the differing parts (keywords, companion keywords, check ID, message) as parameters.

### Regex Correctness

| Mistake | Example | Fix |
|---------|---------|-----|
| Redundant alternatives | `api[_-]?key\|apikey` — the first already matches `apikey` | Remove `\|apikey` |
| Unnecessary escapes in char classes | `[_\-]` — hyphen doesn't need escaping at start/end of `[]` | `[_-]` or `[-_]` |
| Incomplete alternation coverage | Date pattern missing `MM/DD/YYYY` or `2026H1` formats | Enumerate all real-world variants |

### Deprecated thrift `.ttypes` imports (NoPyDeprecatedThriftImport FIXIT)
`lint_root` + `ai_diff_reviewer` flag any new `from x.y.ttypes import Z` (or `.constants`) — thrift-py-deprecated, EOL May 4 2026. Fix: switch to the thrift-python module `.thrift_types` (struct/exception names are identical):
```python
# before:  from aiplatform.modelstore.metadata_service.ttypes import ModelStoreDBRecordNotFound
# after:   from aiplatform.modelstore.metadata_service.thrift_types import (
#              ModelStoreDBRecordNotFound,
#          )
```
Requires the thrift target to generate `python` (check `languages=[...]` in the thrift `BUCK`; if missing `"python"`, you can't switch — the `.thrift_types` module won't exist). `arc lint -a` autodeps swaps the BUCK dep `:foo-py-deprecated` → `:foo-python-types`. For a bigger migration use the `migrate-thrift-py-deprecated` skill. NOTE: per the thrift rule, don't migrate `.ttypes` *proactively* — only when the user asks or a comment/FIXIT demands it.

### Missing Pyre Headers

All Python files in fbcode need pyre strict headers. Add to every `.py` file:

```python
# pyre-strict
```

Check with `arc pyre` before submitting. Reviewers will reject diffs missing this.

### Duplicate Keys in BUCK/Starlark

Starlark silently accepts duplicate keys in a rule — the last value wins, earlier ones are dropped without error. This means adding a second `deps = [...]` silently removes the original dependencies.

| Mistake | Example | Fix |
|---------|---------|-----|
| Duplicate `deps` key | `deps = [":lib"], deps = ["//other:lib"]` — first list silently dropped | Merge into one: `deps = [":lib", "//other:lib"]` |

**Applies to all list keys:** `deps`, `srcs`, `resources`, `visibility`. Always check if the key already exists before adding.

### Incomplete Pattern Coverage

When writing detection patterns (dates, secrets, URLs), enumerate real-world formats exhaustively:

- **Dates:** ISO `YYYY-MM-DD`, US `MM/DD/YYYY`, EU `DD/MM/YYYY`, big-endian `2026H1`, `Q4 2025`, `2025 Q4`
- **Secrets:** `API_KEY`, `api-key`, `apiKey` — cover all casing/delimiter variants
- **Test before shipping:** Generate 10+ real examples and verify your regex matches all of them

## Splitting `.yaml` from `.py` for RADAR Auto-Stamp

Mixing `.yaml` config edits into a `.py` code diff blocks RADAR auto-stamp via the "Restrict specific files" rule — even when the diff is small, low-risk, and CI-clean. The `.py` portion would have auto-stamped on its own.

**Pattern:** when a feature change spans both code and config, create two diffs:

```bash
# Diff A: .py code only
sl goto 'last(public(), 1)'
# edit .py files only
sl addremove
sl commit -m "Add X behavior"
jf submit --draft --publish-when-ready

# Diff B: .yaml config only (dependent or independent)
sl goto 'last(public(), 1)'
# edit .yaml files only
sl addremove
sl commit -m "Wire config for X"
jf submit --draft --publish-when-ready
```

**When NOT to split:** if the `.py` change cannot run without the `.yaml` change landing first (true runtime dependency), bundle them — auto-stamp isn't worth a broken main.

## Devmate Code Reviewer Anti-Patterns

Devmate (not ACR) is the gatekeeper for RADAR auto-stamp. A single Devmate blocking finding kills auto-stamp. Avoid these patterns — each one observed as a real Devmate finding on Denny's recent diffs:

| Anti-pattern | Example | Fix |
|---|---|---|
| Silent except blocks | `except (RuntimeError, json.JSONDecodeError): pass` | Catch specific errors AND log/raise |
| `# pyre-unsafe` in pyre-strict packages | File has `# pyre-unsafe` but BUCK target sets `typing=True` | Drop the unsafe pragma, fix any resulting type errors |
| Tests of private functions | `def test_verdict_label(): _verdict_label(...)` | Test through the public API instead |
| Docstring/code drift | Docstring claims "exact match" but SQL allows superset | Fix one or the other so they agree |
| Stale task refs | Comment references `T266536788` (closed weeks ago) | Remove or replace with current task |
| Inline constants | `FEATURE_CAPABILITIES = [...]` declared in a function body | Move to module-level `constants.py` |
| Redundant rules in skill files | Same instruction at L18 and L60 of a `.md` skill | Devmate flags duplication — keep one |
| Hardcoded URLs / magic numbers / slice indices in code | `fburl.com/scuba`, `limit=100`, `[:5]`, `[:400]` literal in a `.py` | Extract to a `*_config.yaml` or module-level constants. Devmate land-blocks these as "violates ot-agent-conventions" or similar style rules |
| Unvalidated input to a query/exec function | `find_peers(name)` does no allow-list check before string-building a SQL/path/URL | Add a defensive validate at the top of the function (allowlist or regex). Devmate raises this as defense-in-depth even when there's no actual injection vector |
| Enum-like field with placeholder value | `video: TBD` in a yaml whose schema expects `defer`/`auto`/`record` | Use a defined value (e.g. `defer`). `TBD` parses as a literal string and Devmate flags it as a probable bug |
| Inline regex keyword list when the rest of the module reads tunables from yaml | `_RE = re.compile(r"(mvai\|online_train\|publish\|snapshot\|...)")` while numeric thresholds in the same file go through `triage_config.yaml` | Extract keyword lists to yaml too. Build the regex at runtime: `kws = cfg["explicit_signals"]; _RE = re.compile("(" + "\|".join(map(re.escape, kws)) + ")", re.IGNORECASE)`. Inconsistent extraction (numbers yes, keywords no) trips the OT agent conventions rule. (Learned 2026-04-29: D103095467 autolearn) |
| `# pyre-unsafe` on a brand-new fbcode `.py` file | New file scaffolded with `# pyre-unsafe` because that's the local boilerplate; pyre would have passed clean with `# pyre-strict` | Default `# pyre-strict` on every new `.py` and only fall back to `pyre-unsafe` if pyre actually fails AND fixing the errors is genuinely costly. Boilerplate-default `pyre-unsafe` always draws a reviewer question. (Learned 2026-04-29: D103095467 autolearn) |
| Engagement-style test mocks the outer subprocess but not the inner one | `test_engagement_check_skipped_when_no_gchat_url` mocks `_has_ot_ic_engaged_in_space` but leaves `_fetch_gchat_url` unmocked — passes only because the test-env CLI happens to fail | When a test exercises a path with `check_engagement=True` (or any multi-hop subprocess flow), mock EVERY subprocess in the chain. A test that mocks one layer and gets pass-by-luck on another is non-deterministic across machines. (Learned 2026-04-29: D103095467 autolearn) |
| `if __name__ == "__main__": unittest.main()` boilerplate at the end of a new test file | Devmate-rule-attributed to `.llms/rules/python.md`: "Buck handles test discovery and execution, so this boilerplate is not needed per Meta Python conventions." | Drop the block on every new fbcode test file. Pre-submit grep: `grep -l 'unittest\.main' fbcode/<area>/tests/test_*.py`. (Learned 2026-04-30: D103338751 + D103341232 autolearn) |
| Type-helper delegating to a sibling helper of the wrong type, hiding `expected int` behind `expected str` | `def _int(...): raw = _str(...); int(raw)` reports `(expected str)` for a missing int field — the message lies about which type was wanted | Each per-type validator owns its own missing-key + wrong-type messaging. For `_int`: explicitly reject `bool` (subclass of `int`) before accepting `isinstance(v, int)`, then accept `str` and parse, then fall through. Add a regression-pin test that asserts the error says `expected int`, never `expected str`. (Learned 2026-04-30: D103340523 autolearn) |
| `dict.update(extra)` merge on a logger record without a collision check | Caller passes `extra={"capability": "x"}` and silently clobbers the canonical `capability` field in the log record | Namespace caller fields under `record["extra"] = dict(extra)` so they can never overwrite core fields (`capability`, `payload_id`, `verdict`, `signal`, `rationale`). Update tests that assert the flat shape (`emitted["sev_type"]` → `emitted["extra"]["sev_type"]`). (Learned 2026-04-30: D103338751 autolearn) |
| `open()` and side-effecting setup BEFORE the `try:` whose `finally:` cleans them up | Trace handler attached + file opened ABOVE the try block — if any line in between raises, the FD leaks and the handler is permanently attached | Move ALL open + setup INSIDE the `try`. Capture original logger state (`original_level`, `original_propagate`) before mutating, restore in `finally`. Add a regression-pin test that runs `main()` and asserts logger state matches pre-main values. (Learned 2026-04-30: D103339828 autolearn) |
| Logger `.level` / `.propagate` mutated and only `removeHandler` called in `finally` | `_attach_trace_handler` sets level=INFO, propagate=False — finally only removes the handler. Second call in same process inherits the polluted state and trace bleeds into stderr without `--trace` | Always capture `(handler, original_level, original_propagate)` from the attach helper and restore all three in `finally`. The handler removal alone is half the cleanup. (Learned 2026-04-30: D103339828 autolearn) |
| Inconsistent payload identifier across log emission points in the same function | `_emit_unmatched` logs raw `sev.get("sev_number")`, matched path logs `f"S{sid}"` — same SEV gets two different IDs in the log, breaking `grep payload_id=S657101` | Normalize the identifier ONCE at the top of the function and reuse the same variable in every emission. Pattern applies to ANY function where multiple branches log/return with the same entity. (Learned 2026-04-30: D103338751 autolearn) |
| Skill/recipe doc recommending `dict.get("k") or default` for null-safe config reads | Silently replaces ANY falsy value (`0`, `""`, `False`, `[]`), not just `None` — a contributor copies the pattern into a config path where `0` is meaningful and gets the wrong default | Recommend `v = d.get("k"); v if v is not None else default` instead. Audit sibling skill docs that copied the pattern: `grep -rn '" or default' .llms/ cheatsheets/ <area>/references/`. (Learned 2026-04-30: D103341001 autolearn) |
| Submission recipe omits a Task ref required by the area's `.llms/rules/<area>-conventions.md § Diff Submission` | `add-a-capability.md` listed reviewers + tags but skipped `T259215482` mandated by `pe_mrs_ml/mrs_ot_agent/.llms/rules/ot-agent-conventions.md` — Devmate cross-references the conventions rule and flags the doc | Before writing any "submit" guidance: `grep -A 5 "Diff Submission" .llms/rules/*.md` for the relevant area and copy the required fields verbatim. Audit sibling docs for the same drift via `grep -rln "Submit:" <area>/references/`. (Learned 2026-04-30: D103341001 autolearn) |
| `assertLessEqual(len(top_files), N)` structure test fails after adding a new top-level source file | Adding `__init__.py` made `iterdir()` return 10 entries against a limit of 8 — the test was reading the buck link-tree and counting `default.profraw` (coverage artifact) as a source file | Bump the limit AND filter build artifacts (`f.suffix not in {".profraw", ".pyc"}`). The link-tree contains artifacts that aren't in BUCK srcs/resources but still leak in. Update the test in the SAME diff that adds the new top-level file. (Learned 2026-04-30: D103341232 autolearn) |
| Multi-gate `classify`-style function trips flake8 C901 cyclomatic-complexity ≥10 | `sev_type filter + sid check + hard-exclude regex + signal scoring + engagement promotion` together — complexity 13 on `classify()` | **In an additive diff** (logging adds, instrumentation): suppress with `# noqa: C901  — multi-gate filter ladder; complexity is intrinsic to the 5-step decision, not splittable without losing readability`. Helper extraction drops `predicted_accept_rate` from 0.6 to 0.29 (D103338751 v2) — only land the refactor in a SEPARATE pre-diff if cleaner code is worth losing auto-stamp. (Learned 2026-04-30/05-01: D103338751 v2→v3.) |

Read existing Devmate findings on a prior version of the diff with `meta phabricator.diff comments -n D... -o json` and filter for author `Devmate Code Reviewer`. For findings that haven't surfaced as comments yet, query the diff metadata directly: `mcp__plugin_meta_mux__get_phabricator_diff_details(phabricator_diff_number="D...", include_failing_ci_signals=True)` — Devmate land-blockers appear under the failing CI signals before they're rendered as inline comments. Fix all of them before re-submit.

## See Also

`cheatsheets/diff/common.md` (shared patterns), `cheatsheets/diff/review.md` (reviewing), `cheatsheets/diff/fbcode-conventions.md`, `cheatsheets/diff/verification-guide.md`
