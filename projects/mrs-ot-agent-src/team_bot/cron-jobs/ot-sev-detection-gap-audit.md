[ot-sev-detection-gap-audit cron] Weekly Mon ~09:47 PT. INDEPENDENT detection-coverage audit — OT analog of the PE MRS ML team's "SEV audit for lightweight-test gap" (Andrew Mao / Ezra Khuzadi, 2026-06-08). For each OT SEV resolved in the window, check whether automated detection caught it (`auto_detected`); SEVs caught only by humans (dashboards / employee-reports / manual) are detection/test gaps — flag the class so a human adds a detector or lightweight test.

STANDALONE by design (operator directive 2026-06-08, thread S-j4aTzRKng: "build independent job to avoid dependencies"): own script, own schedule, no coupling to the distillation pipeline. Logic lives in the script; this prompt only orchestrates + delivers.

Steps:
1. Run: `bash /home/dennyzhang/notes/users/dennyzhang/projects/mrs-ot-agent-src/team_bot/tools/sev-detection-gap-audit.sh --days=14 --max=40`
2. Read the final line: `GAPAUDIT resolved=N covered=C gap=G skipped=S`.
3. Delivery (operator 1:1 ONLY — Cron Output Effectiveness + Team-Chat Send Gate; NEVER team space):
   - `gap>0`: send ONE crisp digest to the operator 1:1 (spaces/AAQAVOjYc80, `--reply-in-thread` an existing relevant thread or append `# new-topic`):
     `🛟 detection-gap audit (14d): G of N resolved OT SEVs had NO automated detector:` then the gap lines from the script (SEV + [method] + title), then one line: `→ add a detector/lightweight test for these classes.` Then respond `HEARTBEAT_OK`.
   - `gap==0`: respond exactly `HEARTBEAT_OK {gapaudit: clean, resolved: N}`; post nothing.
4. If ≥3 gap SEVs share a model/area (recurring uncovered class), file ONE deduped handhold task (`--owner=dennyzhang` only, no other assignee) naming the class — else NO task. (The task-owner-guard hook enforces owner=dennyzhang.)

Read-only on SEVs (never mutate). Never post to team space. If the script errors (no `GAPAUDIT` line), respond `HEARTBEAT_OK {gapaudit: error}` and surface to 1:1 only if it recurs 2+ runs.
