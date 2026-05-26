# Configerator Diff Cheatsheet

Configerator-specific rules. **Read `cheatsheets/diff/common.md` first** for shared Sapling/JF patterns, submit workflows, gotchas, reviewer discovery, and test plan discovery.

## Creating a New Diff

**HARD RULE — configerator diffs MUST be based on trunk, never on another diff (even a landed one).** `conf submit` does NOT support stacked commits (configerator.md rule line 185), and Phab's `depends_on` link survives the parent landing — a stacked configerator diff is unlandable even after its parent merges. Always create new diffs from trunk:

```bash
sl pull
sl goto 'last(public(), 1)'
# make changes, then commit
```

This ensures diffs are independent and avoids accidental stacking.

**If you ended up stacked anyway** (e.g. forgot to `sl goto` trunk before editing, or rebased a draft onto another draft that later landed): the diff will show `depends_on: D<parent>` on Phab and stay red with `land_blocker` even after the parent closes. Fix:

```bash
sl pull --reason "fetch trunk before rebase - sl help pull"
sl rebase -r D<child> -d remote/master --reason "rebase configerator diff off stacked parent onto trunk - sl help rebase"
meta phabricator.diff remove-dependency -n D<child> -d D<parent>
sl goto D<child> --reason "navigate to rebased diff before resubmit - sl help goto"
jf submit --update-fields
```

Learned 2026-05-26: D106406191 was stacked on landed D106194663 — `depends_on` field on Phab was a phantom land blocker; local rebase + `remove-dependency` cleared it.

## Key Differences from Fbsource

| Aspect | Fbsource | Configerator |
|--------|----------|--------------|
| Type checking | `arc pyre` required | Does NOT apply — skip it |
| Build validation | Not typically needed | `conf build` required — compiles `.cconf` files |
| Formatter | `arc f` (via PostToolUse hook) | `arc f` (manual — PostToolUse hook is fbsource-only) |
| Format standard | Various | BLACK (88-char line limit for `.cconf` Python files) |
| Preflight gate | `arc lint` + `arc pyre` | `arc lint` + `arc build` |

## Pre-Submit Checklist

Before `jf submit`, always run:

```bash
cd /data/users/$USER/configerator   # or /data/repos/configerator
arc f <changed-files>               # BLACK formatting (must do manually)
arc lint                            # lint check
arc build <changed-cconf-files>     # remote full-dependency build — REQUIRED
sl status                           # check for regenerated materialized_JSON
sl addremove                        # stage new/changed materialized files
sl amend                            # amend materialized files into commit
# THEN jf submit
```

**`arc build` is the main validation gate** — it compiles all affected `.cconf` files (including transitive dependencies) via remote build. This is different from `conf build` which only does local compilation. Always use `arc build` as the authoritative validation step.

**Note**: `conf build` requires being inside a valid configerator repo (eden checkout with `.arcconfig`). The non-eden sparse checkout at `/data/users/$USER/configerator` may not be recognized — use the eden checkout at `/data/users/$USER/configerator2` instead.

**`arc pyre` does NOT exist for configerator** — do not attempt it.

## Non-Functional Refactoring Validation

For diffs that are pure refactoring (no behavior change), verify after `arc build`:

```bash
sl diff --stat   # look for materialized_configs/ changes
```

If materialized files changed, the refactoring altered behavior — investigate before landing. A clean refactoring diff should produce **zero** materialized config changes.

## BLACK Formatting Rules

Configerator `.cconf` files are Python and must follow BLACK formatting (88-char line limit):

- **Long assignments**: Parenthesize the value
  ```python
  # Bad
  TRAIN_PUBLISH_EVAL_STAGES = """{"stages_covered": ["train", "publish", "eval"], "goal": 24, "sev3": 72}"""

  # Good
  TRAIN_PUBLISH_EVAL_STAGES = (
      """{"stages_covered": ["train", "publish", "eval"], "goal": 24, "sev3": 72}"""
  )
  ```

- **Long tuple entries**: Break into multi-line
  ```python
  # Bad (exceeds 88 chars)
  ("IGR CS Omni Test", "cogwheel_igr_ss_cs_omni_test", TRAIN_PUBLISH_EVAL_STAGES, cs_omni_notifs),

  # Good
  (
      "IGR CS Omni Test",
      "cogwheel_igr_ss_cs_omni_test",
      TRAIN_PUBLISH_EVAL_STAGES,
      cs_omni_notifs,
  ),
  ```

- **Long function calls**: Keep on one line if under 88 chars, otherwise wrap
- **Always run `arc f`** on changed `.cconf` files before submitting — the PostToolUse hook does NOT auto-format configerator files

## Sparse Checkout

Configerator has 3.6M files. Use sparse checkout for non-eden repos:

```bash
# Enable sparse and include only what you need
sl sparse include .jfconfig .arcconfig
sl sparse include 'source/path/to/your/files/**'

# For arc build, you may need dependency directories too
sl sparse include 'source/conveyor/**' 'source/minimal_viable_ai/**'
```

**Critical**: `.jfconfig` and `.arcconfig` MUST be in the sparse checkout — without `.jfconfig`, `jf submit` fails with "unsupported capability 'submit'".

## Configerator-Specific Gotchas

### PostToolUse `arc f` hook does NOT run on configerator files

The hook is scoped to fbsource paths only. You must manually run `arc f` on configerator files before submitting. Forgetting this is the #1 source of linter errors on configerator diffs.

### Set `{...}` vs list `[...]` matters

The Conveyor framework distinguishes between sets and lists. `gen_app_layer_conveyor` passes `unit_test_nodes` via `nodes.append()`, and the framework handles sets of `SandcastleNodes` but not lists. Don't change collection types without checking how the framework consumes them.

### `conf build` fails in sparse checkout — use eden instead

`conf build` does a local build when only a few files changed, but the sparse checkout can't resolve deep transitive thrift dependencies (e.g., `sigrid/model_id.thrift` imported transitively through `minimal_viable_ai`). **Don't try to expand the sparse checkout** to include missing deps — adding large directories (like `source/sigrid/**`) pollutes `sl status` with thousands of "pending changes" and causes `arc build` to see thousands of spurious changed files.

**Fix:** Run `conf build` in the eden checkout instead:

```bash
# Copy modified source file to eden
cp /data/users/$USER/configerator/source/path/to/file.mcconf \
   /data/users/$USER/configerator2/source/path/to/file.mcconf

# Build in eden (has all deps available)
cd /data/users/$USER/configerator2
conf build source/path/to/file.mcconf

# Copy rebuilt materialized files back to sparse checkout
for f in $(sl status --no-status | grep materialized_configs); do
    cp "$f" /data/users/$USER/configerator/"$f"
done

# Clean up eden
sl checkout --clean .
```

### After rebase, always rebuild materialized configs

After rebasing a configerator diff, the old materialized files no longer match trunk's base. New observers may have been added on trunk, old ones may have been updated. Without a fresh `conf build`, the `configerator-build-and-diff` CI will fail with "file changes absent in your diff."

**Workflow:**
1. `sl rebase -d 'last(public(), 1)'`
2. Rebuild in eden (see above)
3. Copy materialized files back
4. Check for stale materialized files — if `conf build` in eden doesn't modify a file that your diff previously changed, revert it to trunk: `sl cat -r '.^' <file> > <file>`
5. `sl amend` + `jf submit --draft`

### Don't `sl sparse include` large directories temporarily

Adding then removing a large directory from sparse checkout (e.g., `sl sparse include 'source/sigrid/**'`) leaves hundreds of "pending changes" warnings and takes time to clean up. If you need files from a large directory, use the eden checkout.

## Verification Checklist (Configerator Additions)

In addition to the common verification checklist:

| Check | Command |
|-------|---------|
| BLACK formatting clean | `arc f <files>` (no changes made) |
| `conf build` passes | `conf build <cconf-files>` |
| No materialized changes (refactoring) | `sl diff --stat` — no `materialized_configs/` changes |

## Common Mistakes

| Wrong | Right | Why |
|-------|-------|-----|
| Run `arc build` on non-EdenFS sparse checkout | Clone fresh EdenFS repo: `eden clone /data/users/$USER/configerator /data/users/$USER/configerator2` | Non-EdenFS sparse checkouts can't resolve thrift imports. EdenFS has full repo on demand. |
| Use `sl clone --eden` | Use `eden clone <source> <dest>` | `sl clone` doesn't have `--eden` flag. Use the `eden` CLI directly. |
| Skip `arc build` and rely on CI | Always run `arc build` locally — it catches compilation errors before CI | CI failures on configerator diffs are often the same build errors you'd catch locally |
| Run `arc build` but forget to amend the materialized JSON | After `arc build`, always: `sl status` → `sl addremove` → `sl amend` → then `jf submit` | `arc build` regenerates `materialized_configs/*.materialized_JSON` as untracked files. If you don't stage and amend them into the commit, the diff is missing its compiled output and CI will fail. |
| Run `jf submit` before `arc build` | Always run `arc build` BEFORE `jf submit`, then amend + resubmit | Submitting first means the materialized JSON from the build isn't in the diff. The correct order is: `arc build` → `sl addremove` → `sl amend` → `jf submit`. |
| Manually edit `@generated` cconf files | Treat them as read-only and use the generator tooling | Files under `source/ai/model_registry/` and many other domains start with `@generated` — they're produced by upstream cconf tooling (e.g., model registry migration) and manual edits are lost on next regeneration. For IG per-model `criticality_override`, changing a value requires cross-owner signoff, cconf tooling, IG tier-governance limit checks, and MLE approval. (Learned 2026-04-17 while investigating 51 IG OT model overrides.) |

## See Also

`cheatsheets/diff/common.md` (shared patterns), `cheatsheets/diff/review.md` (reviewing)
