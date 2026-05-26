# Reviewer Comment Automation — Spec

The "auto-review-bot" workflow. Cron-driven daemon that scans Denny's reviewer queue, drafts a Phab-style comment when a "major" condition fires on a new revision, and (Phase 0/1) sends the draft to Pylon's GChat space for Denny to review and paste manually. Graduates per-category to autonomous Phab-posting once observation data shows the bot is reliably right.

Same shape as RADAR's auto-stamp progression (`cheatsheets/diff/common.md` § "RADAR Auto-Stamp Optimization"). Mirror that mental model.

## The four phases

| Phase | Scope | Trust model | Risk |
|---|---|---|---|
| **0** (today) | Daemon scans reviewer queue → "major" classifier → draft sent to Pylon space (`spaces/AAQAfjULJM4`) | Denny posts manually | Zero — Denny remains the gate |
| **1** (weeks 1-4) | Same as Phase 0, plus per-draft outcome verdict logged to `diff-comment-learnings.md` | Denny replies `/post`, `/edit`, `/skip`, or `/harm` to each draft | Zero |
| **2** (week 4+) | Per-category graduation check runs weekly inside `cron-diff-autolearn.sh` Mon 6 AM pass | Categories that hit promotion threshold flip to autonomous | Bounded — only proven categories graduate |
| **3** (when first category graduates) | Autonomous posting under Denny's own account with `[auto-review-bot]` prefix + `/denny-mute` killswitch in every comment | Bot acts; Denny monitors AI Health | Low — narrow scope + killswitch + per-category opt-in |

## The "major comment" classifier

Fires when at least one of these conditions is true on a NEW revision in Denny's reviewer queue. Narrow on purpose — a noisy classifier kills the autonomy gradient.

| Category | Trigger | Why |
|---|---|---|
| `ci-fail-non-trivial` | Failed CI signal where signal name does NOT match `arc.*lint|pyre|mypy|autodeps|prettier|black|clang-format` | Test/build failure that needs author attention. Lint failures already auto-fix elsewhere. |
| `test-plan-empty-large-change` | `test_plan` field empty AND `line_count >= 50` AND change is not config-only (touches ≥1 `.py`/`.cpp`/`.hack`/etc.) | Substantive code change with no stated test plan = high-value reviewer prompt |

Future categories (Phase 1.5+, gated on classifier proving accurate): Devmate HIGH/CRITICAL inline finding, stale rebase >14d on a touched fbcode dir.

## What is NOT a major comment

- Lint warnings, pyre advisories, autodeps nags — handled by `cron-diff-signal-monitor.sh` mechanical autofix
- "Uncertain → conservative escalation" — chat-only via the existing midnight scan, not Phab comments
- Diffs Denny already commented on (track via `state/diff-reviewer-state.json` per-version dedup)
- Diffs not in `Needs Review` status (accepted / abandoned / landing — silent)

## Per-version trigger + idempotency

State file `state/diff-reviewer-state.json` schema:

```json
{
  "DXXXXX": {"last_version_id": "1234567890", "drafted_at": "2026-04-29T15:30:00-07:00", "categories": ["ci-fail-non-trivial"]}
}
```

Daemon skips a diff if `latest_version_id == state.DXXXXX.last_version_id`. Author publishes a new version → state diverges → daemon re-runs. Comment-once-per-(diff, version, category).

## The ledger

`~/work/claude/diff-comment-learnings.md` — append-only markdown table. One row per draft AND one row per Denny verdict.

```markdown
| Date (PT) | Diff | Author | Category | Action | Notes |
|---|---|---|---|---|---|
| 2026-04-29 15:30 | D102XXX | foo | ci-fail-non-trivial | DRAFTED | (signal: flow_test_xyz) |
| 2026-04-29 15:42 | D102XXX | foo | ci-fail-non-trivial | POST | (Denny pasted as-is) |
```

Action values: `DRAFTED`, `POST`, `EDIT`, `SKIP`, `HARM`. (`HARM` = posting would have damaged trust — false positive that would have made Denny look bad.)

## Phase 2 graduation thresholds

A category graduates to autonomous mode when ALL three conditions hold over its full ledger history:

| Threshold | Why |
|---|---|
| `count_drafted >= 10` | Statistical floor — fewer obs = anecdote |
| `(count_post / (count_post + count_edit + count_skip)) >= 0.80` | Bot must be right 8/10 in proven category |
| `count_harm == 0` | One harm = reset clock to zero observations |

Computed by `cron-diff-autolearn.sh` weekly (Mon 6 AM pass). Promotion writes to `state/diff-reviewer-graduated.json`:

```json
{
  "ci-fail-non-trivial": {"graduated_at": "2026-05-13T06:00:00-07:00", "obs": 14, "post_rate": 0.86}
}
```

Demotion: any `HARM` verdict in a graduated category resets it to draft-mode immediately. The next weekly pass will only re-graduate after another 10 clean observations.

## Phase 3 autonomous posting (dormant until first graduation)

When a category is in `state/diff-reviewer-graduated.json`, the daemon posts the draft directly to Phab via `meta phabricator.diff comment` instead of sending to Pylon's GChat. The comment body always opens with:

```
[auto-review-bot] <comment>

— Auto-posted by dennyzhang's review automation. Reply `/denny-mute D102XXX` to silence on this diff, or `/denny-mute --category=ci-fail-non-trivial` to silence the category.
```

Killswitch: a separate cron pass scans for `/denny-mute` strings in any inline comment on Denny-reviewed diffs in the last 24h, writes mute targets to `state/diff-reviewer-mutes.json`, and the daemon honors before drafting.

## ⚠️ Soul-rule narrow exception

Soul says NEVER post to Phab. The cron daemon (and only the cron daemon, after a category graduates) is exempt because:

1. Each comment self-identifies as `[auto-review-bot]` (no impersonation)
2. Each comment carries an in-comment killswitch (immediate user control)
3. Categories graduate only after ≥10 observations + ≥80% post-rate + 0 harms (data-driven trust)
4. A single `HARM` resets the category to draft-mode (cheap rollback)

**Interactive Pylon (Claude in chat session) still NEVER posts** — same soul rule applies. The exception is narrow to the cron daemon's `meta phabricator.diff comment` call after graduation.

## AI Health integration

| Surface | Cadence | Content |
|---|---|---|
| AI Health gdoc — daily cron health row | daily 6:15 AM (`cron-ai-health.sh`) | Did `cron-diff-reviewer-comment.sh` run clean today? |
| AI Health gdoc — weekly stats block | weekly Mon 6 AM (`cron-diff-autolearn.sh` extension) | Per-category obs count, post-rate, "N observations from graduation" countdown |
| `AUTOLEARN-CHANGELOG.md` | weekly Mon 6 AM | Category graduation events (or demotions) |

## Routine gdoc daily summary (Option B integration)

Each morning (6:30 AM PT, after nightly-routine-preprocessing finishes
building today's H1 at ~2:45 AM) `cron-diff-reviewer-routine-digest.sh`
appends a 3-5 line summary of *yesterday's* daemon activity to the Routine
gdoc, **dedicated tab "Auto-Review-Bot"** (tab id `t.3oyk41iz0i1x`,
registered in `config/DAILY-DOCS.json` under `routine.tabs.auto_review_bot`).
Tab created 2026-04-29 to keep daemon digests scoped — no pollution of
the main routine flow.

Format:
```
## Auto-Review-Bot - yesterday (YYYY-MM-DD)

| Metric | Value |
|---|---|
| Drafts produced | N |
| Verdicts: post / edit / skip / harm | a / b / c / d |
| Categories near graduation | <name> (need K more obs) |
```

Empty days print a single line: `_No drafts yesterday._`

HARM verdicts trigger a warning block + the next weekly autolearn pass
demotes any affected graduated categories.

Files: `scripts/cron-diff-reviewer-routine-digest.sh`,
`scripts/lib/diff_reviewer_routine_digest.py`. Tests:
`scripts/test_diff_reviewer.py` (RoutineDigestTest class).

## Cron schedule

- New entry: `*/30 9-19 * * 1-5` (every 30 min, 09:00–19:00 PT, Mon–Fri only)
- Reuses `cron_run` wrapper for health reporting
- Lock file `/tmp/cron-diff-reviewer-comment.lock` prevents overlap

## Killswitch (manual)

To pause the daemon entirely (any phase):
```bash
touch ~/work/claude/state/diff-reviewer-paused
```
Daemon checks for this file at start; if present, exits silently.

## Files

| Path | Role |
|---|---|
| `scripts/cron-diff-reviewer-comment.sh` | Main daemon (every 30 min, M-F 9-19 PT) |
| `scripts/cron-diff-reviewer-routine-digest.sh` | Daily Routine gdoc summary (6:30 AM, Option B) |
| `scripts/lib/diff_reviewer_classifier.py` | Categorization logic |
| `scripts/lib/diff_reviewer_ledger.py` | Append + read + graduation predicate |
| `scripts/lib/diff_reviewer_graduation.py` | Phase 2 promotion check (weekly) |
| `scripts/lib/diff_reviewer_post.py` | Phase 3 Phab-post helper (dormant) |
| `scripts/lib/diff_reviewer_routine_digest.py` | Routine gdoc digest renderer (pure function) |
| `scripts/diff_reviewer_record_verdict.py` | CLI Pylon calls when Denny verdicts a draft in chat |
| `state/diff-reviewer-state.json` | Per-version dedup |
| `state/diff-reviewer-graduated.json` | Category graduation registry |
| `state/diff-reviewer-mutes.json` | Mute targets |
| `state/diff-reviewer-stats-block.md` | Weekly stats block for AI Health |
| `diff-comment-learnings.md` | Append-only ledger |
| `scripts/test_diff_reviewer.py` | Unit tests (55 cases) |

## Pre-mortem findings

Append-only log of "should have fired but didn't" cases discovered by post-hoc review of NO_CATEGORIES outcomes. Each entry names the diff, the gap, and the fix.

| Date | Diff | Gap | Fix | Status |
|---|---|---|---|---|
| 2026-04-29 | D103059019 | `test-plan-empty-large-change` missed it. test_plan = `"On an OD:"` (10 chars) — non-empty but semantically vacuous. Classifier's `if test_plan:` check let it pass. Marty 3-ingredient recipe: neutral signal (any non-empty string passes) + no visible correct pattern (no concept of "substantive") + pressure (don't spam). | Added `MIN_SUBSTANTIVE_TEST_PLAN_CHARS=50` floor + `_PLACEHOLDER_TEST_PLAN_RE` regex (matches `automation`, `tbd`, `n/a`, `wip`, `todo`, `pending`, `on an? \w+`, `trivial`, `self-review`, etc.). 8 new tests added. | shipped |

**How to add a row**: every Phase 1 review pass that finds an under-fire case appends here. The fix column should reference the code change (regex addition, threshold tweak, etc.) so future readers can see the evolution.

## See also

- `cheatsheets/diff/common.md` — RADAR Auto-Stamp Optimization (parallel pattern)
- `cheatsheets/system/agent-pressure.md` — Marty Dumaual research synthesis (3-ingredient recipe, hook interference, prompt-pressure swap table)
- `scripts/hook-stack-toggle.sh` — A/B test the Claude Code hook stack (paired with the agent-pressure cheatsheet's hook interference section)
- `scripts/cron-diff-signal-monitor.sh` — sibling daemon (CI signal autofix), shares scan substrate
- `scripts/cron-diff-autolearn.sh` — weekly autolearn pass, extended for Phase 2 graduation
- `memory/feedback_radar_zero_human_review_goal.md` — the "log every outcome immediately" workflow rule
