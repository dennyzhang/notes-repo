# scripts/ — index

Generic, shareable shell tooling for `~/work/claude`. This folder is the backing
store for the `~/work/claude/scripts` **symlink** (same model as `cheatsheets`).

- **Shared here (`.sh` + allowed text files only).** `fb:notes` rejects `.py`/`.plist`.
- **Python lives in `~/work/claude/private_scripts/`** (+ `private_scripts/lib/`), along
  with personal-by-purpose scripts. `.sh` here that call/import `.py` reference them by
  `private_scripts/...` path. See `private_scripts/README.md`.
- **Flat by design.** crontab, hooks, and cross-script `source`/`python3` calls reference
  scripts by flat path, so files stay at the root rather than in per-domain subdirs.

## Cron jobs (scheduled — see crontab / `private_scripts/setup-claude.sh`)

### Health, audit & quality
| Script | Purpose |
|---|---|
| `cron-ai-health.sh` | Daily AI Playbook gdoc health push |
| `cron-ai-audit.sh` | Daily AI automation reliability audit |
| `cron-ai-infra-reliability-miner.sh` | Monthly AI Infra Reliability learning miner |
| `cron-audit-agent.sh` | Daily doc quality evaluation (LLM) |
| `cron-harness-health.sh` | Daily `state/HARNESS-HEALTH.md` |
| `cron-alert-sync.sh` | LLM daily alert dashboard → Google Doc |

### Diff & review
| Script | Purpose |
|---|---|
| `cron-diff-signal-monitor.sh` | Asymmetric-autonomy diff signal monitor (Posture B) |
| `cron-ai-diff-review.sh` | Twice-daily multi-LLM (Claude+Codex+Gemini) review of reviewer queue → Routine gdoc |
| `cron-diff-autolearn.sh` | Weekly reviewer-comment → cheatsheet updates |

### Project, people & knowledge
| Script | Purpose |
|---|---|
| `cron-project-context-refresh.sh` | Weekly project-context harvester orchestrator |
| `cron-project-dashboard.sh` | Per-project `DASHBOARD.md` health metrics |
| `cron-project-tier-assign.sh` | Daily project tier assignment |
| `cron-people-refresh.sh` | Daily people-profile refresh |
| `cron-knowledge-distiller.sh` | Weekly KB compression (LLM) |
| `cron-autolearn-corrections.sh` | Auto-improve cheatsheets from feedback |
| `cron-area-monitor.sh` | Nightly area activity + AI-skill scan |
| `cron-self-improve.sh` | Recursive self-improvement for cron fleet |
| `cron-workflow-regression.sh` | Weekly workflow-rule regression test |
| `cron-workflow-self-eval.sh` | Score a workflow run vs its Eval tab |

### Reporting & digests
| Script | Purpose |
|---|---|
| `cron-daily-progress.sh` | Accumulate shipped work into weekly PSC draft |
| `cron-weekly-report.sh` | Auto-generate weekly PSC draft (Fri PM) |
| `cron-meeting-followups.sh` | AI meeting notes → Meta tasks |
| `cron-gchat-group-digest.sh` | Periodic group-chat summarization |
| `review-digests.sh` | Weekly digest review rollup |

### Context lifecycle
| Script | Purpose |
|---|---|
| `cron-context-expire.sh` | Daily TTL engine for personal context |
| `cron-context-gc.sh` | Weekly context garbage collection |
| `cron-daily-housekeeping.sh` | Validate, scan, anti-sprawl, backup, clean, sync |

### Infra health & sync
| Script | Purpose |
|---|---|
| `cron-keepalive.sh` | SSH mux + google-mux daemon keepalive (10 min) |
| `cron-remediator.sh` | Auto-remediate chronic cron failures |
| `cron-heartbeat-watchdog.sh` | Detect cron jobs that silently stopped firing |
| `cron-disk-cleanup.sh` | Disk cleanup + MyClaw auto-healing (15 min) |
| `cron-auth-sync-nudge.sh` | Nudge to re-auth MyClaw before expiry |
| `cron-dashboard-publish.sh` | Regenerate cron dashboard HTML |
| `cron-notes-push.sh` | Daily push of `~/notes` to master |
| `cron-sync-to-github.sh` | Commit + push workspace to GitHub |
| `cron-file-sync.sh` | Bidirectional Mac ↔ devserver file sync |
| `cron-upstream-outside.sh` | Check external GitHub repos for updates |

## Shared libraries (sourced, not run directly)
| Script | Purpose |
|---|---|
| `cron-alert.sh` | Alert/heartbeat framework + `cron_run`, `get_doc_id`, `get_gchat_space` |
| `enforce-prerequisites.sh` | "Read X before doing Y" enforcement + hard blocks |
| `enforcement-log.sh` | Shared enforcement metrics logging |
| `fetch-cache.sh` | Shared cache for expensive API calls |
| `file-lock.sh` | Atomic file-level locking for concurrent sessions |
| `lib/` | Shared `.sh` helpers (`gdocs_lib.sh`, `llm-dispatch.sh`, `cron-helpers.sh`). Python helpers (`gdocs_helper.py`, `llm-dispatch.py`, `ai_health*.py`, `diff_multi_llm_review.py`) live in `private_scripts/lib/`. |

## Google Docs helpers
| Script | Purpose |
|---|---|
| `gdocs-safe-replace.sh` | Comment-safe wrapper for `gdocs replace` (mandatory; see CLAUDE.md) |
| `gdocs-safe-write.sh` | Comment-safe wrapper for all gdoc write ops |
| `gdocs-cleanup-empty-lines.sh` | Delete empty paragraphs |
| `gdocs-cleanup-stale-claude-replies.sh` | Delete superseded `[Claude]` placeholder replies |
| `generate-ai-health-html.sh` | `AI-HEALTH.md` → styled HTML for gdocs |

## Diff / commit / quality gates
| Script | Purpose |
|---|---|
| `rebase-diff.sh` | Atomic rebase of a Phabricator diff onto trunk |
| `git-review.sh` | Bucketed git diff for spot-checking |
| `lint-diff-summary.sh` | Standalone diff-summary linter |
| `sl-summary-lint-hook.sh` | Sapling `pretxncommit` diff-summary lint |
| `block-stacked-commit.sh` | PreToolUse hook for `sl`/`hg` commit |
| `quality-gate-precheck.sh` | Deterministic pre-delivery checks |

## Hooks / settings / lint
| Script | Purpose |
|---|---|
| `lint-settings.sh` | Validate `settings.json` before/after edits |
| `render-hooks.sh` | Regenerate `settings.json` hooks block from config |
| `hook-stack-toggle.sh` | A/B test the hook stack |
| `generate-autolearn-changelog.sh` | Rebuild `AUTOLEARN-CHANGELOG.md` |

## OT (online training) tools
| Script | Purpose |
|---|---|
| `ot-delta-status.sh` | Check sparse/dense delta + full snapshot for an OT model |
| `ot-fleet-health.sh` | MRS OT fleet health scanner |
| `cron-oncall-shift-summary.sh` | Post-process the OT Oncall Shift gdoc |
| `gpu-test-queue.sh` | GPU test queue runner |

## Misc tooling
| Script | Purpose |
|---|---|
| `new-project.sh` | Scaffold a new `projects/<slug>/` |
| `commit-digest.sh` | Split working tree into SIGNAL/STATE buckets |
| `token-budget.sh` | Claude Code token-budget dashboard |
| `generate-dashboard.sh` | Generate a Markdown project dashboard |

## Manual / occasional utilities (not cron-scheduled, run by hand)
| Script | Purpose |
|---|---|
| `scan-cron-errors.sh` | Lint cron scripts for error-swallowing patterns |
| `backfill-cron-jobs.sh` | One-off cron backfill after a server reinstall |
| `push-to-github.sh` | Manual claude-repo commit + GitHub push |
| `sync-from-devserver.sh` | One-way devserver → Mac sync |
| `test-harness.sh` | Smoke tests for harness infrastructure |
| `test-hooks.sh` | Fixture smoke tests for hook scripts |
| `ai-health-gdoc-template.sh` | AI Playbook gdoc table-width spec (glue; currently orphaned) |

## Subdirectories
| Dir | Contents |
|---|---|
| `lib/` | Shared `.sh` helpers (Python helpers are in `private_scripts/lib/`) |
| `harvesters/` | Project-context signal harvesters (`diffs-by-*`, `posts-by-author`, …) |
| `cron/` | Cheatsheet-flywheel cron scripts + prompts |
| `hooks/` | Standalone hook scripts (diff/gdocs/phab guards) |
| `lint/` | Cheatsheet lint + dedup + accept scripts |
| `learnings/` | Auto-save-learnings reference |
