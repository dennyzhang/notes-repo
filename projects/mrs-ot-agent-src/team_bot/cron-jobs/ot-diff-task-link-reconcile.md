[ot-diff-task-link-reconcile cron] Weekly Mon ~09:00 PT. Heals the diff↔task association failure class — bot-authored diffs whose TITLE asserts a `T###` task but whose Phabricator `tasks:` field is empty (task filed after the diff, `Tasks:` line stripped on amend, Unpublished/proposal diffs, cross-session creation). A point-in-time create+verify can't catch those; a reconciliation sweep can. Logic lives in the script (thin-prompt rule); this prompt only orchestrates.

Steps:
1. Run the reconciler in APPLY mode (additive link backfill only — never unlinks; capped at 25/run; audited to reconcile-diff-task-links.log; each backfill verified):
   `bash /home/dennyzhang/notes/users/dennyzhang/projects/mrs-ot-agent-src/team_bot/tools/reconcile-diff-task-links.sh --apply --limit=80`
2. Read the final machine line: `RECONCILE candidates=N backfilled=M failed=F apply=1`.
3. Delivery (Cron Output Effectiveness + Team-Chat Send Gate — this is operator-facing hygiene, 1:1 ONLY, never team space):
   - If `backfilled>0` OR `failed>0`: send ONE line to the operator 1:1 (spaces/AAQAVOjYc80, `--reply-in-thread` an existing relevant thread or append `# new-topic`):
     `🛟 diff↔task reconcile: backfilled M link(s){, F FAILED — investigate}`. Then respond exactly `HEARTBEAT_OK`.
   - Else (`backfilled=0 failed=0`): respond exactly `HEARTBEAT_OK {reconcile: clean, candidates: 0}` and post nothing.

Never post to team space. Never unlink. If the script errors (non-zero / no RECONCILE line), respond `HEARTBEAT_OK {reconcile: error}` and surface the error to the 1:1 only if it recurs 2+ runs.
