# Thread Summary: Diff-Cheatsheet Hook Creation + apply-space-hooks.py Durability + Notes Repo Structure

_Source: spaces/AAQAVOjYc80 thread `rLh3PKgXCmA` · 34 messages · 2026-05-31_
_Summarized: 2026-06-01 04:45 PT · last-msg-time: 2026-05-31T02:50:14Z_

## What was discussed

Denny asked whether there was a hook enforcing the diff cheatsheet gate on every `jf submit`. There wasn't — only a narrow weekly-sync duplicate-submit guard existed. The bot added a 4th PreToolUse hook that blocks every `jf submit`/`conf submit` until the escape token `# diff-cheatsheet-ok` is present (asserted after running the full Pre-Submit Gate self-review). A secondary investigation revealed that `apply-space-hooks.py` had never been landed to fbcode stable — it existed only inside unlanded weekly-sync mirror drafts — so the hook's reinstall durability wasn't actually guaranteed. The bot also addressed Denny's questions about directory structure: `scripts/` folder in fbcode (not notes — `.py` denylisted), and whether `human-input/` should move to `mrs-ot-agent-context/` (rejected: ~10 relative links in SKILL.md would break + true duplicates already exist).

## Key decisions made

- **2026-05-31T02:33** New PreToolUse hook added: blocks every diff submit until `# diff-cheatsheet-ok` token present. Escape token only goes on after running `cheatsheets/diff/common.md` + repo cheatsheet + area `.llms/rules`.
- **2026-05-31T02:33** Hook mirrored to `team_bot/apply-space-hooks.py` (canonical installer, re-installed by bootstrap.sh). Idempotent; tested.
- **2026-05-31T02:35** Denny: "commit and push to notes repo" — bot pushed the pending `.md`/`.json` changes (not the `.py` — denylisted).
- **2026-05-31T02:38** `human-input/` move to `mrs-ot-agent-context/` rejected by bot; Denny's response: "why ask" → bot acted without asking.
- **2026-05-31T02:40** Denny asked about converting `apply-space-hooks.py` to `.sh`. Bot's position: keep Python (JSON read-modify-write on settings.json is fragile in bash; `.py` problem is solved by landing to fbcode trunk, not language change).
- **2026-05-31T02:44** Land attempt abandoned: `apply-space-hooks.py` has never been in fbcode/stable; landing it collides with the existing weekly-sync draft that adds it. Safe approach: first-land it standalone to `team_bot/scripts/apply-space-hooks.py` after the draft stack settles.

## Files / artifacts touched

| path | what changed |
|---|---|
| `team_bot/apply-space-hooks.py` | 4th hook spec added (diff-cheatsheet gate) |
| `spaces/AAQAVOjYc80/.claude/settings.json` | 4 PreToolUse hooks live (thread-reply, weekly-sync guard, submit-dedup, diff-cheatsheet) |
| notes master | pushed 5 files: MANIFEST + daily-brief + ot-triage-summary + 2 state (`11643c3fc210`) |

## Cluster / pattern references

_(omitted — failure-patterns.md does not exist yet)_

## Followup items (not yet done)

1. Land `apply-space-hooks.py` standalone to `team_bot/scripts/apply-space-hooks.py` in fbcode (worktree or after draft stack settles) — current hook is live but not reinstall-durable.
2. Update `bootstrap.sh` path reference once the file moves to `scripts/`.

## Cross-refs

- Diffs: D106859537 (the diff that skipped the gate, triggering this thread)
- Related threads: `S2zrir2qpBY` (submit-guard context), `Q_8ELeVd7cU` (cron-level cheatsheet enforcement)
