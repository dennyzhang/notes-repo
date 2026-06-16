# Task Execution Cheatsheet

Quick reference for executing tasks reliably across servers. Distilled from 25+ sessions and 14 documented failures on the snapshot-test-flakiness project. Expands on the execution discipline rules in CLAUDE.md.

## The 3 Rules

Every failure in the snapshot project traces back to violating one of these:

### 1. Verify Before AND After

**Before** any command:
```
- Does the target exist?
- Is the checkout correct? → sl log -r . -T '{phabdiff} {desc|firstline}\n'
- Do timeouts come from config (MODEL_CONFIG.yaml), not hardcoded?
- Is the server the right one for this task?
```

**After** any command:
```
- Never say "done" without pasting output that proves it
- Never say "submitted" without showing the diff number
- Never trust exit code alone → verify with "Ran N tests" + "OK" in output
- Exit code 0 with tee can mask failures (tee returns 0 even if test crashes)
```

### 2. Diagnose Before Retry

```
Failure → Read FULL error → Check ERROR-CATALOG.yaml → Find root cause → Fix

NOT: Failure → Same command again → Hope for different result
```

**Escalation ladder:**
- 1st failure: diagnose, fix root cause, retry
- 2nd failure: reassess entire approach
- 3rd failure: write ESCALATION.md, stop, ask for help

### 3. Track Time and Entities

```
- State expected duration BEFORE long operations
- Use validation matrix for multi-entity work (model × diff × server)
- Never confuse "X passed on diff A" with "X passed on diff B"
```

## Pre-Flight Checklist

Run before any command on a remote server:

```bash
# 1. Correct server?
hostname

# 2. Correct checkout?
cd /data/repos/fbsource && sl log -r . -T '{phabdiff} {desc|firstline}\n'

# 3. No stale processes?
ps aux | grep "buck2 run" | grep -v grep

# 4. Certs valid?
date -r /var/facebook/credentials/$USER/x509/$USER.pem

# 5. GPU available?
nvidia-smi | head -20
```

## SSH Commands

### Pattern
```bash
ssh -F /dev/null -o ControlPath=~/ssh-mux/%h <hostname> '<command>'
```

### Rules
- Always prefix repo commands with `cd /data/repos/fbsource &&` — SSH sessions start in the home directory, not the repo root
- If ControlMaster socket is missing → ask user to set up (don't attempt direct SSH)
- Never embed heredocs in SSH command strings — heredoc delimiters break shell quoting when nested inside SSH strings. Write to a remote file first, then run it.
- Server list: inline in `scripts/cron-keepalive.sh` and `scripts/setup-claude.sh` (source of truth: `config/INFRASTRUCTURE.md` Devservers table)

### Writing scripts to remote servers
```bash
# Write script to remote file
ssh server 'cat > /tmp/script.sh << '\''EOF'\''
#!/bin/bash
echo "hello"
EOF'

# Run it
ssh server 'bash /tmp/script.sh'
```

## Background Process Management

### When to background
- Any operation >10 seconds: `run_in_background: true`
- GPU tests: always via `nohup` + redirect — SSH disconnects kill foreground processes, losing test results
- Never use foreground `sleep` or blocking waits >30s — blocks the user's ability to interact with the session

### Launching GPU tests
```bash
ssh server 'cd /data/repos/fbsource && \
  nohup timeout 2700 buck2 run fbcode//path/to:test \
  > /tmp/test.log 2>&1 &'
```

### Checking status
```bash
# Process alive?
ssh server 'ps aux | grep "buck2 run.*test_name" | grep -v grep'

# Latest output?
ssh server 'tail -5 /tmp/test.log'

# Result?
ssh server 'grep "^Ran " /tmp/test.log'
```

### Never block the conversation
- User's ability to interact is the priority
- Use `run_in_background: true` for monitoring waits
- Check status on-demand, don't make user wait behind a timer

## Multi-Server Coordination

### Checkout Drift Detection
When running multi-round benchmarks, verify checkout hasn't changed between rounds:
```bash
EXPECTED_HASH="abc123"
CURRENT=$(sl log -r . -T '{node|short}')
if [ "$CURRENT" != "$EXPECTED_HASH" ]; then
  echo "DRIFT: expected $EXPECTED_HASH, got $CURRENT"
  exit 1
fi
```

### Parallel Server Utilization
- Never let a GPU server sit idle if there's work to do
- Queue the next test immediately after one finishes
- Track which server runs which test (validation matrix)

## Exit Code Reference

| Exit Code | Meaning | Action |
|-----------|---------|--------|
| 0 | Success (usually) | Verify with `Ran N tests` + `OK` in output |
| 0 with tee | May mask failure | Check actual test output, not tee's exit code |
| 1 | Test failure | Read traceback, diagnose root cause |
| 70 | Feed U2I specific failure | Check diff stack — may need upstream fix |
| 124 | Shell timeout (killed) | Check if timeout value matches MODEL_CONFIG.yaml |
| 137 | SIGKILL (OOM or manual) | Check `dmesg` for OOM, or was it manually killed? |

## Error Diagnosis Quick Reference

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| NCCL hang at shutdown | Known gloo/os._exit issue | Shell timeout catches it (2-tier timeout) |
| Manifold 404 | Stale model entity ID | Re-run with fresh entity |
| cert expired | x509 cert >24h old | User runs `fbwallet_fetch` |
| output buffering | Non-TTY Python buffering | Use `PYTHONUNBUFFERED=1` |
| `size_in_bytes=0` | Sparse delta publish quirk | Known issue — log it, don't fail on it |
| compress_net shape mismatch | Batch size mismatch with model | Check `--batch-size` matches MODEL_CONFIG.yaml |

## Self-Check (Every 5 Tasks or 1 Hour)

5-second mental scan:
- Am I verifying before AND after commands?
- Did I just report something without acting on it?
- Is a GPU server sitting idle?
- Have I been stuck >30 minutes without progress?
- Am I tracking multi-entity status correctly?

If any answer is "no" → fix immediately.

## 2-Hour Stall Rule

If a diff development task has been running for more than 2 hours without completion, stop and diagnose:

### Immediate Actions

1. **Time check** — note actual elapsed time vs original estimate. Log the gap in TASKS.md.
2. **Root cause analysis** — identify why it's taking longer than expected:
   - Repeated test failures without root-cause fix?
   - Yak-shaving (fixing unrelated issues to unblock the real task)?
   - Unclear requirements causing rework?
   - Infrastructure problems (server issues, flaky builds, cert expirations)?
   - Unfamiliar codebase without enough upfront exploration?
   - Scope creep (task grew beyond original definition)?
3. **Document the findings** — append to TASKS.md under the task entry:
   ```
   **Stall Analysis (2h+):**
   - Elapsed: Xh Ym
   - Root cause: <one-line summary>
   - Attempted approaches: <what was tried>
   - Remaining work: <what's left>
   ```

### Decision Tree

| Situation | Action |
|-----------|--------|
| Clear path forward, <30 min remaining | Continue, but set a hard 30-min timer |
| Blocked by infrastructure or access | Escalate to user immediately |
| Root cause unclear after diagnosis | Escalate to user with findings |
| Scope grew beyond original task | Escalate — user decides whether to split or continue |
| Repeated failures (3+ retries on same issue) | Escalate — likely needs a different approach |

### Escalation Format

When escalating, provide:
```
**Task Stall — Need Input**
- Task: <task name / diff number>
- Elapsed: <time spent>
- Root cause: <why it stalled>
- What I tried: <approaches attempted>
- Options: <2-3 concrete next steps for the user to pick from>
```

### Future Prevention

After the task completes (or is abandoned), record a lesson learned:
- What would have caught the stall earlier?
- Should the task have been split into smaller pieces?
- Was there a missing prerequisite (codebase exploration, design review)?
- Update ERROR-CATALOG.yaml if a new failure pattern was discovered.

## Meta Tasks Rules

### Subtask Attachment

When breaking a Meta Task into subtasks, **always attach subtasks to the parent task**. Orphaned subtasks are invisible from the parent view and lose the hierarchical context.

- The `tasks_cli.py create` command does not support `--parent`. The GraphQL `internal_task_edit` mutation throws server exceptions for parent/subtask fields from devservers.
- **Workaround**: After creating subtasks, tell the user to attach them in the UI. Include the parent task URL and all subtask T-numbers so it's a single copy-paste action.
- **Never skip this step.** If programmatic attachment fails, surface it immediately — don't silently leave subtasks orphaned.

## Autonomous Task-to-Diff Mode

When asked to "work on task T12345" or "implement this task", follow this pipeline end-to-end without asking intermediate questions:

### Pipeline

1. **Read the task**: `meta search.doc search -q "T12345" --doc-type=TASK -o json` or `knowledge_load`. Extract: title, description, acceptance criteria, linked diffs/tasks.
2. **Load context**: Read the repo-specific diff cheatsheet (`cheatsheets/diff/fbcode.md`, etc.) and any referenced files from the task description.
3. **Create worktree**: Use EdenFS worktree or `sl checkout -b` to isolate changes.
4. **Implement**: Write the code. Follow the 3 Rules above (verify before/after, diagnose before retry, track time).
5. **Validate**: Run `arc lint -a`, pyre check (fbcode), and relevant tests. Fix lint/pyre issues.
6. **Submit draft**: `jf submit --draft`. Never publish — human reviews first.
7. **Write result**: Append to `context/cache/ENQUEUED-DIFFS.md`:
   ```
   | Date | Task | Diff | Status | Summary |
   | YYYY-MM-DD | T12345 | D98765 | draft | One-line what changed |
   ```
8. **Link task**: Add `Tasks: T12345` to the commit message so the diff links back.

### Guardrails

- **Draft only** — never `jf publish` or land.
- **Limited scope** — one task = one diff. Don't scope-creep.
- **3-failure stop** — if implementation fails 3 times, write findings to TASKS.md and stop.
- **No prod changes** — skip tasks that modify production configs, OT publishing, or tier designations. Flag these for manual handling.

### Background Mode

When run via `claude -p` (cron or background agent), the pipeline runs unattended. Results appear in `ENQUEUED-DIFFS.md` and surface in `/my-start` the next morning: "N overnight diffs ready for review."

## Anti-Patterns

| Don't | Do Instead |
|-------|-----------|
| Ask "Want me to do X?" when the answer is obvious | State "Doing X now" and execute in the same response |
| End analysis/focus with a question | End with the action you're taking + expected timeline |
| End a review with a question | End with "Fixed N issues, pushed" |
| Report failure and wait | Act immediately — debug, retry, or escalate |
| Hardcode timeout values | Read from MODEL_CONFIG.yaml |
| Run same failed command again | Diagnose root cause first |
| Use foreground sleep >30s | Use `run_in_background: true` |
| Assume diff stack order | Verify from Phabricator first |

## See Also

- `cheatsheets/diff/fbcode.md` — Sapling/Jellyfish diff workflows (fbsource)
- `cheatsheets/diff/configerator.md` — Sapling/Jellyfish diff workflows (configerator)
- `cheatsheets/diff/verification-guide.md` — Parallel pyre/lint/test verification

_Last updated: 2026-05-12. Maintainer: dennyzhang._
