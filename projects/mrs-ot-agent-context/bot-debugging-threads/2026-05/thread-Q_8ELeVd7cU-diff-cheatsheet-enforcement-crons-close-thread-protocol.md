# Thread Summary: Diff-Cheatsheet Enforcement in Crons + Close-Thread Protocol + Submit-Guard Bypass Analysis

_Source: spaces/AAQAVOjYc80 thread `Q_8ELeVd7cU` · 101 messages · 2026-05-31_
_Summarized: 2026-06-01 04:45 PT · last-msg-time: 2026-05-31T04:28:06Z_

## What was discussed

A long multi-topic session covering three connected issues that surfaced after D106859537 skipped the diff cheatsheet gate:

**1. Diff cheatsheet enforcement in crons.** Denny: "cron should follow the same cheatsheet rules as agents." Bot audited all 5 diff-submitting crons — only `ot-knowledge-distillation` actually produces a diff for review; the others are `--no-submit` or already token-gated. The distillation cron was missing an explicit gate step. Fixed: added proactive pre-submit self-review step to its prompt + synced notes→sqlite (three-layer flow).

**2. Submit-guard hook bypass analysis.** Denny challenged the bot to adversarially probe the new hook. Two real vulnerabilities found: (a) the naive "contains `jf submit`" substring match false-blocked read commands that contained the string (`jf submit | grep ...` as part of checking, gchat exemption) AND could be evaded by piping (`jf submit | grep`); (b) a `grep`-based exemption in the hook was checking the whole command string, not the first word. Fixed: first-word-only read detection + tighter match logic. Simulated 13 cases; all passed.

**3. "Close the thread" protocol.** Denny formalized: "Fixed" ≠ "Closed." Closing = 3 steps: (a) adversarially attack the fix for bypasses, (b) memorize the learning in MEMORY.md, (c) move the generic lesson to a cheatsheet so it's discoverable. Applied immediately to the submit-guard fix → added to `cheatsheets/system/ARCHITECTURE.md` § Writing & Hardening Guard Hooks.

**4. Cron prompt three-layer flow recurrence.** D106859537 itself skipped the gate because crons run self-contained prompts (don't load interactive cheatsheet). Confirmed: enforcement requires tool-layer hook (catches all submits) + explicit gate step in each cron prompt + cheatsheet documents the token. Only distillation + weekly-sync actually submit.

## Key decisions made

- **2026-05-31T03:01** Denny extended: crons must follow the same cheatsheet rules as agents. Bot fixed `ot-knowledge-distillation` submit step (notes + sqlite parity verified).
- **2026-05-31T~03:10** Submit-guard hook hardened: first-word read-tool skip instead of substring match. 13-case simulation confirmed.
- **2026-05-31T~03:30** "Close the thread" protocol formalized as standing rule (thread `Q_8ELeVd7cU`) — attack → memorize → generalize to cheatsheet.
- **2026-05-31T~04:00** Generic principle written to `cheatsheets/system/ARCHITECTURE.md` § Writing & Hardening Guard Hooks (covers false-positive risk + evasion analysis for all future hooks).

## Files / artifacts touched

| path | what changed |
|---|---|
| `cron-jobs/ot-knowledge-distillation.md` | added explicit diff-cheatsheet gate step before submit |
| `myclaw.db` jobs table | distillation prompt synced via `readfile` + SHA256 parity verified |
| `cheatsheets/system/ARCHITECTURE.md` | new section: Writing & Hardening Guard Hooks |
| `spaces/AAQAVOjYc80/.claude/settings.json` | submit-guard hook hardened (first-word match, not substring) |
| `team_bot/apply-space-hooks.py` | submit-guard spec updated to match live hook |

## Cluster / pattern references

_(omitted — failure-patterns.md does not exist yet)_

## Followup items (not yet done)

_(none explicitly open at thread close — all three issues resolved and generalized)_

## Cross-refs

- Diffs: D106859537 (the distillation diff that triggered this whole thread)
- Related threads: `rLh3PKgXCmA` (hook creation), `S2zrir2qpBY` (submit-guard origin)
- Memory entries saved: `feedback_close-the-thread-protocol`, `gotcha_submit-guard-hooks-match-substring`, `gotcha_cron-prompt-three-layer-flow`
