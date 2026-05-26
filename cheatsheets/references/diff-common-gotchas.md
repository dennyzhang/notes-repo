## Common Gotchas
## Common Gotchas

### 1. Phabdiff association lost after amend

`sl amend` (with or without `-m`) creates a new commit hash and can lose the phabdiff metadata even though the `Differential Revision:` footer is still in the commit message text.

**Always verify after amend:**
```bash
sl log -r . -T '{phabdiff}\n'
```

If empty but the footer is in the message, `jf submit` will usually still find the right diff from the message footer. But verify after submit.

### 2. jf submit timeout

`jf submit` often exceeds the 2-minute Bash tool timeout.

**Workaround:** Use `timeout: 180000` on the Bash call, then verify:
```bash
sl log -r . -T '{phabdiff}\n'
```

### 3. Description not updating

Symptoms: `jf submit` says "updated" but `jf diff-properties` still shows old description.

**Root cause:** No code change → `jf submit` skips the diff.

**Fix:** `jf submit --draft --update-fields --no-skip`

### 4. Checking what Phabricator actually shows

```bash
# Full diff properties
jf diff-properties D12345678 | jq '.'

# Just the test plan
jf diff-properties D12345678 | jq -r '.message' | grep -A 30 "Test Plan:"

# Version info (published vs draft)
jf diff-properties D12345678 | jq '{status: .status, latest: .latest_phabricator_version.number, draft: .latest_draft_phabricator_version.number}'
```

If `latest` and `draft` version numbers differ, the published version is stale.

### 5. Writing commit messages via SSH

Never embed heredocs inside SSH command strings. Write the message to a remote file first:

```bash
# Write message to remote file (use single-quoted heredoc delimiter)
ssh server 'cat > /tmp/msg.txt << '\''EOF'\''
commit message here
EOF'

# Amend on remote
ssh server 'cd /data/repos/fbsource && sl amend -m "$(cat /tmp/msg.txt)"'
```

### 6. Differential Revision footer lost after stack operations

When creating new commits with a `Differential Revision: .../revision/new/` placeholder and then rebasing/reordering, `jf submit` may amend a different copy of the commit, leaving the working stack with stale placeholder footers.

**Symptoms:** `sl log -r . -T '{phabdiff}\n'` shows empty after `jf submit` succeeded.

**Fix:** Amend the footer and resubmit:
```bash
# Fix footer on specific commit
sl metaedit -r <hash> -m "$(sl log -r <hash> -T '{desc}' | sed 's|Differential Revision: .*/revision/new/|Differential Revision: D12345678|')"

# Resubmit the stack to sync dependencies
jf submit --draft -r <bottom>::<top>
```

**Prevention:** After `jf submit` on a stack, always verify all commits have correct footers:
```bash
sl log -r "ancestors(.) & draft()" -T "{node|short} {phabdiff} {desc|firstline}\n"
```
If any `{phabdiff}` is empty, fix with `sl metaedit` before proceeding.

### 7. Single-diff submit drops stack dependencies

Submitting a single diff (`jf submit --draft`) in a stack does NOT set Phabricator dependency links. Only `--stack` sets dependencies.

**Symptoms:** After `jf submit` on one diff, its parent diff no longer shows as a dependency in Phabricator. `jf diff-properties` shows `"depends_on_diffs": {"nodes": []}`.

**Fix:**
```bash
# After ANY single-diff operation, restore the chain:
jf submit --draft --stack --update-fields --no-skip
```

**Prevention:** Never use `jf submit` without `--stack` on stacked diffs.

### 8. `jf add-reviewer` creates duplicate Reviewers field

When the commit message already has an empty `Reviewers:` field (from `jf submit`), `jf add-reviewer` appends a second `Reviewers:` line at the bottom instead of populating the existing one. The duplicate causes Phabricator to ignore the reviewers entirely.

**Symptoms:** `jf submit` warns "Field 'reviewerPHIDs' occurs twice in commit message!" and the diff shows no reviewers on Phabricator.

**Fix:** Consolidate into a single `Reviewers:` line:
```bash
# Write fixed message to temp file (merge the two Reviewers lines into one)
sl log -r . -T '{desc}\n' > /tmp/fix-msg.txt
# Edit /tmp/fix-msg.txt: remove the empty Reviewers: line, keep the one with names
sl metaedit -l /tmp/fix-msg.txt
jf submit --draft --update-fields --no-skip
```

**Prevention:** After adding reviewers, always verify with `sl log -r . -T '{desc}\n' | grep -c 'Reviewers:'` — should return exactly 1.

### 9. `sl amend` on wrong commit in a stack

`sl amend` always amends the **current checkout**, not necessarily the commit you intend. When working on a new diff stacked on top of another, editing files and running `sl amend` will amend the parent if you forgot to `sl goto` the right commit first.

**Symptoms:** Your edits get folded into the wrong diff. The child commit may get orphaned or need restacking.

**Prevention:** Before `sl amend`, always verify you're on the right commit:
```bash
sl log -r . -T '{phabdiff} {desc|firstline}\n'
```

### 10. Linter reverts changes during amend/commit

Some hooks run linters that can silently revert your code changes. If a linter reformats or reverts a file during `sl amend` or `sl commit`, your edits are lost.

**Symptoms:** After `sl amend`, the diff shows no changes or shows reverted code. System reminders may show the file was "modified by a linter."

**Fix:** Re-apply edits, commit again. If the linter keeps reverting, check if the code violates a style rule (line length, unused imports, etc.) and adjust.

**Prevention:** After `sl amend`, always verify the diff contains your changes:
```bash
sl diff -r '.^' -r .
```

### 11. `jf unlink` strips Differential Revision footer → creates new diff

`jf unlink` removes the dependency between two diffs by editing commit messages. But it also strips the `Differential Revision:` footer, so the next `jf submit` creates a brand new diff instead of updating the original.

**Symptoms:** After `jf unlink` + `jf submit`, you get a new D-number. The original diff is orphaned.

**Fix:** After `jf unlink`, immediately check and restore the footer before submitting:
```bash
# Check footer
sl log -r . -T '{desc}\n' | grep 'Differential Revision'

# If it points to the wrong diff or is missing, fix it
sl log -r . -T '{desc}\n' > /tmp/fix-msg.txt
# Edit /tmp/fix-msg.txt: restore correct Differential Revision line
sl metaedit -l /tmp/fix-msg.txt
jf submit --draft --update-fields --no-skip
```

**Prevention:** Always verify `sl log -r . -T '{phabdiff}\n'` immediately after `jf unlink`.

### 12. Phabricator dependencies survive `jf unlink` — use `meta` CLI to remove

`jf unlink` only removes the dependency from the commit message. Phabricator server-side dependencies survive `jf submit`. Use the `meta` CLI instead:

```bash
meta phabricator.diff remove-dependency --number=D12345 --dependency=D67890
```

This directly removes the "Depends On" link on Phabricator. Alternatively, use the Phabricator UI: go to the diff → "Edit Related Revisions" → remove the dependency.

### 13. Accidental dependency from committing on top of a draft

Creating a new commit while checked out on an existing draft commit causes `jf submit` to auto-create a "Depends On" link in Phabricator — even if the two diffs are completely unrelated.

**Symptoms:** New diff shows "Depends On: D<unrelated-diff>" in Phabricator.

**Root cause:** `sl commit` was run while the working copy parent was a draft commit (not a public commit). `jf submit` interprets the sapling parent→child relationship as a diff dependency.

**Fix:**
```bash
meta phabricator.diff remove-dependency --number=D<your-diff> --dependency=D<unrelated>
```

**Prevention:** Always `sl goto 'last(public(), 1)'` before creating an independent diff. See "New diff from scratch" workflow above.

### 14. Repeated metaedit + submit creates duplicate diffs

Each `sl metaedit` creates a new commit hash. If the `Differential Revision:` footer doesn't survive or `jf submit` can't match the new hash to the existing diff, it creates a brand new diff. Doing this in a loop (edit summary → submit → edit again → submit) spawns one orphaned draft diff per iteration.

**Real example (D97647113):** Four `sl metaedit` → `jf submit` cycles created 4 separate diffs (D97646647, D97646751, D97647025, D97647113) for the same work. Three had to be manually abandoned.

**Prevention:**
1. Get the commit message right BEFORE the first `jf submit` — don't iterate on summaries via metaedit+submit loops
2. After every `sl metaedit`, verify the footer survived: `sl log -r . -T '{phabdiff}\n'`
3. If the phabdiff is empty after metaedit, restore it before submitting:
   ```bash
   sl log -r . -T '{desc}\n' > /tmp/fix-msg.txt
   # Append: Differential Revision: https://phabricator.internmc.facebook.com/D<number>
   sl metaedit -l /tmp/fix-msg.txt
   ```
4. If orphaned diffs were created, abandon them: `meta phabricator.diff abandon -n D<number>`

**Root cause discipline:** Write the diff summary once, review it, then submit. Polishing summaries through repeated submit cycles is expensive — each one risks creating an orphan.

### 15. `--reason` is `sl`-only — don't pass it to `jf` or `arc`

`--reason` is required on every `sl` invocation (per SessionStart hook rules), but `jf` and `arc` don't accept it. Passing `--reason` to `jf submit`, `jf sync`, `arc lint`, etc. causes `Unrecognized arguments` errors.

**Rule:** `--reason` goes on `sl` commands only. Never on `jf` or `arc`.


| Running independent queries sequentially | Use `asyncio.gather` for independent queries. Always add `LIMIT` clause to prevent unbounded results. (Learned 2026-04-01: routine doc comment autolearn) |

### 16. `meta paste create` with inline content hits ARG_MAX around 130KB

When creating a paste from large JSON (fleet scan results, many models), passing content inline on the command line can exceed shell ARG_MAX (~130KB). Symptoms: "Argument list too long" or silent truncation.

**Fix:** Use compact JSON. Before piping to `meta paste create`, shrink whitespace:

```python
import json
content = json.dumps(data, separators=(',', ':'))  # not indent=2
# then pipe or use --input-file
```

Or stage to a temp file and pass `--input-file` when the CLI supports it. Rule of thumb: if your content is >100KB, use file-based input; if >50KB, use compact JSON. (Learned 2026-04-17: D100866286 v5 paste creation.)

### 17. Mid-stack amend rebases children, but they don't auto-resubmit

When you amend a diff in the middle of a stack, sapling auto-restacks every child (gives them new commit hashes). But `jf submit` only uploads the commit you're currently on. **Every rebased child needs its own `jf submit`** — otherwise Phabricator's "Depends On" view stays pointing at the old (now obsolete) parent hashes.

**Symptoms:** After amending a mid-stack diff and submitting it + the top, the middle of the chain shows stale on Phabricator (parent linkage broken, dependency view incoherent). `sl smartlog` may show `x` (obsolete) markers next to old hashes that Phabricator still references.

**Fix:** After any mid-stack amend, walk every child and resubmit:
```bash
# Goto each rebased child in turn and submit
sl goto <child-hash> && jf submit --draft --update-fields
```

**Better — use `--stack`:** A single `--stack` submit handles the whole chain in one shot:
```bash
jf submit --draft --stack --update-fields
```

(See #7 for why `--stack` is the right default for any stacked work.)

**Real example (2026-05-01, D103482259 stack):** Amended D103341001 to drop a yaml change, sapling auto-restacked D103465147 and D103482259. Submitted D103482259 directly but forgot D103465147 — Phabricator showed D103482259 depending on the OLD D103341001 hash for ~10 minutes until operator caught it. Lesson: when any mid-stack edit happens, either submit every child or use `--stack`.
