# Notes Repo (Sapling) — Operations Cheatsheet

_Created 2026-05-16 after 7 file-tracking casualties in one session caused by `sl`-operation misuse during push-divergence recovery. Living document — update when new traps are hit._

_Updated 2026-05-20: added "user-bookmark dead-end" + "public-commit rebase trap" sections after a 90-minute push debugging session._

## The 1-line summary

`sl push --to master`. **Never** `--to remote/default`. **Never** `sl goto --clean` for divergence recovery — use `sl shelve` + `sl pull` + `sl rebase -d master` instead.

## Daily-use commands

```bash
# Check status
cd ~/notes && sl status [path]

# Add SPECIFIC files (NEVER add directory — files disappear silently)
sl add path/to/file1 path/to/file2

# Commit + push
sl commit -m "..." path/to/file1 path/to/file2
sl push --to master

# Verify push landed (REQUIRED before claiming success)
sl cat -r master path/to/file | grep <marker>

# View file at a specific revision
sl cat -r <hash_or_bookmark> path/to/file

# View accumulated changes for a folder over N days (in browser)
sl log -r "last(public() & date('<YYYY-MM-DD'), 1)" -T '{node|short}\n'  # get baseline hash
sl diff -r <baseline> -r . -- path/to/folder/ | pastry                    # paste for web viewing
# Open the paste URL — renders diff with syntax highlighting
```

## The push-divergence dance (when "Root is too far behind" fires)

```bash
# 1. Shelve dirty state files (don't lose them)
sl shelve --name <descriptive>

# 2. Pull latest from master
sl pull

# 3. Rebase your commits onto master
sl rebase -d master

# 4. Resolve any conflicts (DON'T accept defaults blindly — see "Conflict trap" below)
# 5. Push
sl push --to master

# 6. Unshelve dirty state
sl unshelve <name>

# 7. VERIFY: sl cat -r master <each-file-you-cared-about> | wc -l
```

## Anti-patterns (proven harmful tonight)

### ❌ `sl push --to remote/default`

**Wrong bookmark.** Notes repo uses `master`. `remote/default` either doesn't exist or points somewhere stale; pushes appear to succeed but don't land where you expect.

**Cost tonight:** ~12 pushes to wrong target before the cron self-discovered the correct bookmark at 12:21 PT.

### ❌ `sl push` (no `--to`)

**Silent no-op + misleading errors.** Bare `sl push` / `hg push` tries to push to the default destination without a target bookmark. Symptoms:
- `no changes found` → looks like nothing to push, but commits are real.
- `Bundle2 error` / `B2xTreegroup2 unexpected EOL` → looks like a server flake.
- These errors lead you to file mononoke oncall when the actual fix is one CLI flag.

**Cost 2026-05-20:** ~45 minutes lost chasing "server-side bug" before realizing `--to` was missing.

**Replacement:** `sl push --to master` ALWAYS. There is no scenario in the notes repo where bare `sl push` is correct.

### ❌ `sl push --to <unixname> --create` (user bookmark)

**Pushes land but are INVISIBLE in the code browser.** `https://www.internalfb.com/code/notes/users/<u>/` only shows `remote/master` — not user bookmarks. Pushing to `remote/<unixname>` succeeds at the protocol level but Denny / anyone else clicking the URL sees nothing.

**Worse:** once your commits are reachable from `remote/<unixname>`, they become **public phase** locally. `hg rebase` then refuses with `can't rebase public commit`, and `hg phase -df` is a no-op because phases are managed by remotenames. You've trapped your stack.

**Cost 2026-05-20:** 7 important commits pushed to `remote/dennyzhang` looked successful but didn't render at the URL Denny was checking. Then rebase onto master refused. Had to fall back to the `revert --include 'users/<u>/**'` workaround below.

**Replacement:** for notes repo where you own `users/<unixname>/`, push directly to master via `sl push --to master`. User bookmarks are for fbsource-style feature branches, not for content publishing.

### ❌ `sl goto remote/default --clean`

**Destructive to untracked files.** `--clean` discards working-tree changes; if a state file was modified but not committed, it's GONE. If a brand-new file was created but not committed, it's GONE.

**Cost tonight:** wiped `notes-to-fbcode-sync.sh`, `alert-state.json`, 5 cron prompts, 4 mega-learning files.

**Replacement:** `sl goto master` (without `--clean`) + shelve dirty state first.

### ❌ `sl add <directory>`

**Adds whatever it can see at that moment.** Files created AFTER `sl add` but BEFORE `sl commit` get silently skipped. If a rebase happens mid-add, files disappear without warning.

**Cost tonight:** dropped W17 + W18 (mega-learnings/) and CLUSTERS.md (separately).

**Replacement:** `sl add path/to/file1 path/to/file2` — list every file explicitly.

### ❌ `.gitkeep` or other non-allowlisted extensions

**Notes repo `deny_files` hook blocks all extensions not on the allowlist.** Allowed: `.md`, `.txt`, `.json`, `.jsonl`, `.yaml`, `.yml`, `.sh`, `.bash`, `.toml`, `.sql`, `.conf`, `.rules`, `.png`, `.jpg`, `.svg`, `.html`, `.css`, `.lua`, `.vim`, `.gitignore`, `.hgignore`, and a few more. Everything else is rejected at push time.

**Cost 2026-05-16:** `.gitkeep` placeholder for empty `mitigated-alerts/` directory was blocked. Push failed with `deny_files matched name pattern`.

**Replacement:** Use `README.md` instead of `.gitkeep` for empty directories. Bonus: it documents the directory's purpose.

### ❌ `sl commit -m "..."` (no path arg)

**Commits everything dirty in the working tree.** Including state files some cron just wrote, including files you don't intend. Surprise commits → surprise pushes → harder to bisect when something breaks.

**Replacement:** `sl commit -m "..." path/to/file1 path/to/file2` — explicit paths only.

### ❌ Trusting `sl push` reported success

`sl push` can report success on a no-op push (when your local commits had nothing new vs. master). It can also push a commit but the bookmark update fails downstream — your data is on the server, but `master` doesn't point to it.

**Discipline:** every push followed by `sl cat -r master <path> | grep <marker>` to verify the actual content is queryable from master.

## The conflict trap (during rebase --continue)

When `sl rebase` hits a merge conflict and you `sl resolve --mark`, the rebase silently MERGES OUT files that exist in your shelved/draft commits but not in the base you're rebasing onto. Two cases:

1. **You added a new file in draft commit A, rebasing onto base that doesn't have it → file gets dropped during merge.** Looks like normal resolution. File is gone from the rebased commit.
2. **You modified an existing file in draft commit A, rebasing onto base where the file was deleted → conflict, you `--mark`, file disappears.**

**Symptom:** after `sl rebase --continue` reports success, run `sl files -r .` and compare to what you expected. If any file is missing, recover via `sl cat -r <draft-commit-hash> path > path` before pushing.

## The eden-mount stale-snapshot issue

Notes repo is an Eden virtual mount. `sl pull` sometimes pulls a snapshot older than what's actually on remote — when multiple devservers or sessions are writing in parallel, you can pull a state that doesn't include your most recent push from the same session.

**Mitigation:** before any `sl pull`, check current remote with `sl log -r remote/master -T '{node|short}\n'`. After pull, re-check. If hash didn't advance to what you expected, retry the pull.

## The public-commit rebase trap (and the revert-snapshot workaround)

**Trap:** if you've already pushed your stack to `remote/<unixname>`, those commits are public. Standard recovery (`sl rebase -d master`) refuses.

**Workaround — collapse the stack as a single commit on master via working-tree snapshot:**

```bash
# 1. Get to current master
cd ~/notes && sl update remote/master

# 2. Revert your user-dir to the state at the top of your stack
sl revert --all -r <your-top-commit> --include 'users/<your-unixname>/**'

# 3. Sanity-check the diff
sl status | awk '{print $1}' | sort | uniq -c   # expect A=new, M=modified, no .bak/.tmp etc.
sl status | grep -E '\.(bak|tmp|swp|orig|rej|pyc)$'   # MUST be empty

# 4. Commit + push
sl commit -m "collapse: <description>"
sl push --to master
```

**Why this works:** `sl revert -r <rev> --include <path>` brings BOTH added-files and modified-files from that revision into the current working tree, regardless of whether they exist in the current commit. Master commit + your snapshot = clean linear push.

**Watch out:** revert won't bring in files that exist in your draft but were _deleted_ in master since you forked. Run `sl files -r <top>` vs `sl files -r master` if any deletes are suspected.

**Cost 2026-05-20:** without this, the 42 auto-sync commits + 7 content commits would have required either (a) `hg histedit` on public commits (forbidden) or (b) re-applying changes by hand. The revert-snapshot collapsed everything in ~3 commands.

## The `.bak` / `.tmp` deny_files landmine

The `deny_files` hook on push allowlist is strict. Common offenders that sneak in via auto-sync commits:
- `*.bak` — created by editors / scripts that back up before write
- `*.swp`, `*.swo` — vim swap files
- `*.orig`, `*.rej` — left over from merge conflicts
- `*.pyc`, `*.pyo` — Python bytecode
- `*.tmp`, `*.temp`

**Symptom:** `deny_files for <hash>: Denied filename '...' matched name pattern '...'`

**Detection (run before any push):**
```bash
sl files -r . | grep -E '\.(bak|swp|swo|orig|rej|tmp|temp|pyc|pyo)$'
```

**Fix (single offending commit):**
```bash
sl forget <offending-file>
rm <offending-file>   # or mv to /tmp
sl amend
```

**Fix (multiple commits, file added mid-stack):** use the revert-snapshot workaround above — it side-steps the bad commit entirely by replaying the final state without intermediate history.

**Prevention:** add to `.hgignore`:
```
syntax: glob
*.bak
*.swp
*.swo
*.orig
*.rej
*.tmp
*.pyc
```

## File recovery (when something disappears)

```bash
# 1. Find a commit that has the file
sl log -r 'all() & file(path/to/file)' --limit 5 -T '{node|short} {date|isodate} {desc|firstline}\n'

# 2. Recover the content
sl cat -r <commit_hash> path/to/file > path/to/file

# 3. Re-add + commit + push
sl add path/to/file
sl commit -m "[recovery] ..." path/to/file
sl push --to master
```

**Tonight's recovery uses of this pattern:** 7 distinct files. Worked every time. The data was always durably on a commit somewhere — the working tree was just stale.

## Bookmark inventory

```bash
sl bookmarks --remote 2>&1 | grep -E '^\s+remote/(master|@notes/[^/]+/|T)'
```

Useful bookmarks today (verified):
- `master` — canonical default branch
- `remote/@notes/users/<unixname>/<feature>` — personal feature branches (don't push here unless you own the unixname)
- `remote/T<task-id>-<purpose>` — task-scoped branches

## When push fails — fastest decision tree

```
sl push --to master FAILED
│
├── "non-fast-forward" → someone else pushed. sl pull + sl rebase -d master + retry
│
├── "Root is too far behind" → your local stack is too far behind master.
│     ↳ sl shelve, sl pull, sl rebase -d master, sl unshelve, retry push
│
├── "deny_files for X matched name pattern" → file extension blocked
│     ↳ rename file (e.g., .manifest → .manifest.txt), update references, retry
│
├── "Conflicts while pushrebasing: [PushrebaseConflict {left: X, right: Y}]"
│     → master has X.path concurrent-modified
│     ↳ sl pull + sl rebase -d master + manually resolve + retry
│
├── "B2xTreegroup2 / unexpected EOL" → Mononoke protocol flap (intermittent)
│     ↳ Retry once. If persistent, file mononoke oncall.
│
└── "journal.dirstate: no such file" → harmless, push usually succeeded anyway
      ↳ Run sl push again immediately to confirm
```

## Pre-commit checklist

Before `sl commit`:
1. `sl status` shows ONLY the files you intend to commit (no surprise dirty cron-state files)
2. The files you'll add are listed via `sl add <file1> <file2>` (not directory)
3. Working dir contents match what you intend (no untracked stuff from an aborted rebase)

Before `sl push`:
1. `sl log -r . -T '{node|short} {desc|firstline}\n'` shows the commit you intend to push
2. `sl log -r remote/master -T '{node|short}\n'` is the parent you expect to push onto

After `sl push`:
1. `sl cat -r master <each-file> | grep <marker>` returns expected content
2. `sl files -r master <dir>` shows the file count you expect

## Cron-prompt edit cycle (from RULES.md)

When editing a cron prompt, the SIX-step order matters:

1. Edit notes copy: `~/notes/.../mrs-ot-agent-src/team_bot/cron-jobs/<cron>.md`
2. `sl commit + sl push --to master`
3. **Verify push landed**: `sl cat -r master <path> | grep <marker>`
4. Mirror to fbcode: `cp <notes-path> <fbcode-path>`
5. Run `bash ~/fbsource/.../team_bot/setup-cron-jobs.sh`
6. **Verify daemon picked up edit**: `sqlite3 ~/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db "SELECT id FROM jobs WHERE id='<cron>' AND prompt LIKE '%<marker>%';"`

Skipping steps 2-3 ("ship fast, fix later") creates the "on-disk reverted, daemon cached" trap — daemon runs the cached long version, looks fine in production, until next `setup-cron-jobs.sh` reverts daemon to the short on-disk version.

## Tonight's casualty log (for empirical reference)

| # | File | Caused by | Recovery |
|---|---|---|---|
| 1 | notes-to-fbcode-sync.sh | sl goto remote/default --clean | sl cat -r <prior-commit> + sl add |
| 2 | alert-state.json (wiped contents) | sl goto during divergence recovery | Manually re-populated 5 known alert IDs |
| 3 | mega-learnings/2026-W20.md (reverted) | sl rebase conflict | sl cat -r <prior-commit> |
| 4 | mega-learnings/2026-W17.md + W18.md | sl add directory | rewrote from source data |
| 5 | mega-learnings/CLUSTERS.md | sl rebase conflict | recreated from memory + verified |
| 6 | Cron prompts (notes copies) | sl rebase | Recovered from daemon DB |
| 7 | mega-learnings/2026-W19.md + TREND | sl rebase during sjd-coverage-map updates | sl cat -r af6ccddf7423 |

## 2026-05-20 casualty log

| # | Symptom | Root cause | Fix |
|---|---|---|---|
| 1 | `sl push` returned `no changes found` then `Bundle2 error` | Bare push with no `--to` flag | `sl push --to master` |
| 2 | Push to `remote/dennyzhang` succeeded but content not visible at `internalfb.com/code/notes/users/dennyzhang/...` | User bookmarks aren't rendered by code browser; only `master` is | Re-push to master |
| 3 | `sl rebase -d remote/master` aborted with `can't rebase public commit` | Commits became public via user-bookmark push; `hg phase -df` no-op due to remotenames | Revert-snapshot workaround (see above) |
| 4 | `deny_files for <hash>: Denied filename '...ot-cron-health-state.json.bak'` | Auto-sync cron accidentally committed editor backup file | `sl forget` + amend (didn't work due to public phase) → revert-snapshot bypasses the bad commit |
| 5 | First rebase attempt ate the local commit ("destination already has all its changes") | Used `--tool ':local'` which kept destination side everywhere | Aborted rebase, switched to revert-snapshot workaround. For future: `:other` keeps the source-of-rebase side |

Total time lost: ~90 min. Net result: all 7 important commits landed on master as `d36cf0d8df99`.

## See also

- `~/.myclaw-ot-bot/RULES.md` § "Notes-repo push discipline"
- `~/.myclaw-ot-bot/RULES.md` § "Where state files live"
- `cheatsheets/CHEATSHEET-INDEX.md`
