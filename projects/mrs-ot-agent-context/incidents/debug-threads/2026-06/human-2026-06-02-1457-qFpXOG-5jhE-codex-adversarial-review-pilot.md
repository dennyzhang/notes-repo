---
name: codex-adversarial-review-pilot
human_involved: true
thread_id: qFpXOG-5jhE
space: spaces/AAQAVOjYc80
first_msg: 2026-06-02T21:57:30Z
last_msg: 2026-06-02T22:14:29Z
messages: 29
summarized: 2026-06-03 00:43 PT
---

# Thread Summary: Codex Cross-Model Adversarial Review Pilot

_Source: spaces/AAQAVOjYc80 thread `qFpXOG-5jhE` · 29 messages · 2026-06-02 14:57–15:14 PT_
_Summarized: 2026-06-03 00:43 PT · last-msg-time: 2026-06-02T22:14Z_

## What was discussed

Denny asked whether to try a Jason Yanowitz post's suggestion: have Claude launch Codex for adversarial review with `file:line` evidence. The bot said yes and outlined where it fits (validator pass, pre-jf-submit diff review). Operator said "why ask" — bot then executed: verified codex CLI availability, ran a headless smoke-test on the gdoc comment guard hook (which it had shipped earlier), and on first run codex found 3 real bugs. Bot fixed all three and wired the pilot into the Validator Pass governance.

## Key decisions made

- **Codex headless recipe confirmed** (2026-06-02T22:04): `codex exec --skip-git-repo-check "<prompt>" < /dev/null` works; `--skip-git-repo-check` required outside a trusted git repo; `< /dev/null` stops stdin wait; otel-cert warning non-fatal.
- **3 real bugs found and fixed in gdoc-comment-guard hook** (2026-06-02T22:07–22:12):
  - `:35` — gate let `if gdocs apply` / `/usr/local/bin/gdocs apply` bypass the guard.
  - `:42` — `gdocs<TAB>`/newline before `apply` bypassed the space-only match.
  - `:64` — commentless docs falsely blocked (`grep -c` exits 1 on zero matches → tripped fail-safe).
  All fixed; full guard matrix 10/10 pass.
- **Pilot wired into Validator Pass governance** (2026-06-02T22:12): notes `CLAUDE.md` updated (ground truth), mirrored to fbcode + local copies. Scope: code/diff-bearing triage + pre-jf-submit diff review. Pure SEV/alert/gdoc triage keeps Claude validator (no `file:line` anchor). Cron-path auth unverified — fall back to Claude if codex errors in cron.
- **Pilot verdict: keep** — it found 3 bugs Claude had missed on day 1, including a real security bypass of the guard it was reviewing.

## Files / artifacts touched

| path | what changed |
|---|---|
| `notes/.../team_bot/CLAUDE.md` | Cross-model adversarial review (codex) pilot section added |
| `~/.claude/settings.json` (or equivalent hook) | gdoc-comment-guard hook fixed (3 bypass bugs closed) |
| fbcode + local `CLAUDE.md` copies | mirrored, verified identical |

## Cluster / pattern references

_(No CL-NNN clusters defined in failure-patterns.md)_

- Same-model validator = theater; cross-model catch is real (proved day 1 with 3 bugs).
- Jason Yanowitz post: "Don't trust; verify; demand file/line evidence between agents" maps directly to the gdoc-clobber failure this session (subagent self-reported "203 preserved" with no evidence).

## Followup items (not yet done)

1. Verify codex availability from cron/daemon path (auth/cert) — currently unverified; if it errors in cron, fall back to Claude Agent validator.
2. 1-week pilot measurement: track real catches vs Claude-only validator; formalize if it continues surfacing issues Claude missed.

## Cross-refs

- Related threads: `8IyKRxB9wPE` (gdoc clobber that motivated this pilot)
