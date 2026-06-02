[ot-sev-tag-review cron] Daily, weekday morning. Find OT SEVs missing the right tags. Three categories:

**OUTPUT CHANNEL = OPERATOR 1:1 ONLY (2026-05-30 migration).** This cron is operator-facing plumbing with no team-wide value — its output must NEVER appear in the team space `spaces/AAQA2bZMw24`. Mechanism: for any real/actionable output, make an EXPLICIT `meta google.chat.message send --space-name=spaces/AAQAVOjYc80 --reply-in-thread=<existing thread, or append `# new-topic`> --text="…"` to the operator 1:1, THEN respond with EXACTLY `HEARTBEAT_OK` (nothing else) so the daemon's default team-channel auto-delivery posts nothing. NEVER emit a post-block, summary, or narration as your final response — the daemon auto-delivers the final response to the team space `spaces/AAQA2bZMw24`. No-op runs: just `HEARTBEAT_OK`.

**Rendering rules (apply to every SEV line in the output):**
- **Never append `https://www.internalfb.com/sevmanager/view/<num>` after a SEV id.** GChat auto-linkifies bare `S<num>` tokens, so the trailing URL is pure noise. Same for `D<num>` (diff), `T<num>` (task). Drop the entire URL-sourcing pre-fetch step — we don't render URLs anymore.
- **Order SEVs by status + severity within each section.** Status: In Progress first, then Mitigated, then Closed/Resolved. Within status, by level: L1 > L2 > L3 > L4. Stable secondary sort: SEV id descending (newer first).
- SEV line format: `S<num> — L<level> <status> | <title> | owner: <unixname> | <one-liner of why surfaced>`.

| Cat | Source | Auto-apply? |
|---|---|---|
| 0 | BROAD SWEEP — open SEVs that look OT-related but missing `mvai-online-training`. Sub-A (high confidence) auto-applies; Sub-B (heuristic) proposes for review. | Sub-A: yes; Sub-B: no |
| 1 | SEVs the oncall called out as OT-related but missing `mvai-online-training` | yes |
| 2 | SEVs *you* judge impactful for OT but missing `mvai-online-training-review` | no (Denny decides) |

Sub-A + Cat 1 auto-apply per Autonomous Action Allowlist (CLAUDE.md). Sub-B + Cat 2 (judgment calls) propose-only.

Files:
- DB (state): /home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/myclaw.db
- Asked-questions ledger: /home/dennyzhang/.myclaw-ot-bot/spaces/AAQAVOjYc80/sev-tag-asked.json
  Format: {"asked": [{"sev_id": "S123456", "tag": "mvai-online-training", "asked_at": <epoch>}, ...]}

Procedure:

**Category 0 — broad sweep for OT SEVs missing the tag:**

0a. Pull all in-progress SEVs created in last 14 days:
    meta sevmanager.sev list --in-progress --created-after="14 days ago" --columns=sev_number,level,title,owner_unixname,status,created,sev_type,url -o json --limit 300

0b. For each SEV, fetch current tags via `meta sevmanager.sev metadata --sev=S<id> -o json`. Skip if `mvai-online-training` already in tags. Batch this — slow CLI; cap 50 metadata fetches per run if candidate set large.

0c. Classify against OT scope using title + owner_unixname:
    - **Sub-A (auto-apply, high confidence)** — sev_type ∈ {`Production`, `Instagram`}. Exclude `Ads`, `Whatsapp`, `WhatsApp`, `Wearables`, `Oculus`, etc. Then title contains EXPLICIT OT signal:
        /(online[ ._-]?train|online_train_publish|TGIF.*publish|ifu[._-]?lsr|MRS[._-]?OT|mtml|mvai-training-online-|OT[ _-]?(job|stream|training)|\bOT\b.{0,40}(publish|train|crash|block|stuck|stall))/i
      OR owner_unixname is known OT owner (dennyzhang, lupaul, jamespz, llu6, zhengw, zlzhao, paullu).

      **Sub-A demotion list (DEMOTE → Sub-B even if regex matched).** MVAI is a platform; only the `mvai-training-online-*` job-prefix family is OT-in-scope per `.llms/rules/ot-agent-conventions.md`. Demote Sub-A → Sub-B (propose, don't auto-apply) if title contains ANY of:
        /(\bmigration\b|\bcogwheel\b|\boffline\b|\brecurring\b|trunk_metrics_test|_test\b|\bnon-online\b)/i
      Calibration 2026-05-12: bare `mvai` matched 3 false positives in one day — S662458 (LTV migration), S662450 (cogwheel test), S661936 (cogwheel test). Bare `mvai` removed from Sub-A regex above; demotion list added as a backstop for "mvai" mentions wrapped in non-online-training context (e.g., "mvai_ifr_main cogwheel", "mvai_ig_ranking trunk_metrics_test"). Source: operator pushback gchat thread lxtjUKnLuFw.

      **Confidence over regex membership.** If a SEV title contains the literal phrase "online training", "OT jobs", "OT stream", "online_train", or any `mvai-training-online-` prefix, treat as Sub-A regardless of which regex group fires (and ignoring the demotion list — explicit OT signal beats heuristic exclusion). Asking the operator about an obviously-OT SEV is a process bug, not safety.
      Calibration sources (2026-04-29, 3 iterations): (i) title-only `mtml` matched Ads SEV S656968 — sev_type gate fixes. (ii) sev_type=Production-only excluded S652695 (sev_type=Instagram, real OT) — extended to {Production, Instagram}. (iii) bare `publish` regex matched Ads S652258 (`audience_network_publisher_features`) — tightened to `publish(?!er)`. S654315 is canonical Sub-A example.
      Calibration 2026-05-05: S658165 (`IG OT jobs crashing on model publishing`) and S657606 (`threads feed u2m online training blocked`) were dropped to Sub-B because (a) `online[._-]?train` regex required separator (no space), and (b) `OT jobs` token absent. Both are obviously Sub-A. Regex extended; principle codified above.
    - **Sub-B (propose, heuristic)** — sev_type ∈ {Production, Instagram} (same gate) AND title matches broader regex with no explicit OT signal:
        /(\bmvai\b|publish(?!er)|snapshot|delta|streaming|hedwig|silvertorch|gmpp|NCCL|model.age|ATS|scribe.lag)/i
      Note: bare `mvai` lives in Sub-B (propose-only), not Sub-A — see demotion-list calibration above.
    - **Out of scope** — neither matches → skip.

0d. For each Sub-A candidate, AUTO-APPLY: `meta sevmanager.sev update --sev=S<id> --add-tag=mvai-online-training`. Capture per-SEV success/failure.

0e. For each Sub-B candidate, add to propose list (Cat 0-B section).

**Category 1 — oncall-flagged OT SEVs:**

1. Get latest oncall summary post in MRS Online Training Users Workplace group:
   meta workplace.group activity-feed --group-id=1084744250286987 --columns=post_id,author,message,publish_time --limit=20 -o json
   Filter to posts whose first 200 chars match /Oncall Summary for mrs_online_training/ (case-insensitive). Take most recent.
   If no Workplace post in last 7 days, fall back to oncall.feed task with that title:
     meta oncall.feed list --oncall=mrs_online_training --status-is=Open --title-contains="Oncall Summary for mrs_online_training" --limit=5 -o json
   Read the body of whichever was found.

2. Extract all unique SEV references via regex `\bS\d{6,}\b` from the body.

3. For each extracted SEV id, check current tags via `meta sevmanager.sev metadata --sev=S<id> -o json`. If `mvai-online-training` not present AND not auto-tagged in 0a above → Cat 1 candidate. Cat 1 always auto-applies (oncall summary = high-confidence ground truth).

**Category 2 — impactful SEVs by your judgment:**

4. List recent SEVs (last 7 days) — reuse 0a data; filter to candidates whose title, owner team, or existing tags suggest MRS / online-training / ranking / training / publish relevance.

5. For each candidate, mark impactful if ANY:
   - severity is SEV0, SEV1, or UBN
   - severity SEV2 with: customer-facing impact in title/summary, OR duration >1h, OR cross-team escalation, OR major MRS pipeline named (online training, ranking, publish, snapshot)
   - SEV is MITIGATED/RESOLVED but has #postmortem-needed or similar review tag

6. For each impactful SEV, check tags. If `mvai-online-training-review` NOT present → Cat 2 candidate (propose only).

**Dedupe + send:**

7. Read sev-tag-asked.json. Drop propose-only candidates (Cat 0-B, Cat 2) whose (sev_id, tag) pair was asked in last 14 days. Prune entries older than 30 days. Auto-tag actions ignore the asked ledger.

8. Apply Cat 1 + Cat 0-A auto-tags via `meta sevmanager.sev update --sev=S<id> --add-tag=mvai-online-training`. Capture per-SEV success/failure.

9. If 0 surviving items across all categories AND 0 auto-tags applied: respond HEARTBEAT_OK. Do NOT send a message.

10. Otherwise, send ONE batched message to spaces/AAQAVOjYc80 via gchat skill. Format:

    📋 [Daily SEV tag review — N applied / M to review]

**URL sourcing — REMOVED 2026-05-05.** See Rendering Rules at top.


    **Category 0-A — auto-applied #mvai-online-training (explicit OT signal in title):**
    (Order by status: In Progress > Mitigated > Closed; then by level L1>L2>L3>L4; then sev_id desc)
    1. ✓ S<id> — L<level> <status> | <title> | owner: <unixname> | pattern: <which regex group hit>
    2. ...
    (or ✗ S<id> — failed: <reason>)

    **Category 1 — auto-applied #mvai-online-training (oncall summary flagged):**
    (Same ordering)
    1. ✓ S<id> — L<level> <status> | <title> | owner: <unixname> | flagged by <author>
    2. ...

    **Category 0-B — REVIEW: missing #mvai-online-training (genuinely ambiguous, your call):**
    (Same ordering. If a candidate has any literal OT phrase in title, it does NOT belong here — promote to Sub-A. This category is for keyword-match-only cases without explicit OT vocabulary.)
    1. S<id> — L<level> <status> | <title> | owner: <unixname> | heuristic: <which regex group>
    2. ...
    Reply with the SEV IDs to tag (or "skip all").

    **Category 2 — REVIEW: missing #mvai-online-training-review (judged impactful, your call):**
    (Same ordering)
    1. S<id> — L<level> <status> | <title> | owner: <unixname> | reason: <why impactful>
    2. ...

    Cap 15 total items in the message (auto-tagged shown first, then to-review). If more, say "(N more suppressed; will retry tomorrow)".

11. After successful send, append all proposed (Cat 0-B + Cat 2) candidates to sev-tag-asked.json with current epoch. Auto-tagged ones don't need to be remembered.

12. Respond HEARTBEAT_OK.

Safety:
- AUTO-APPLY actions limited to `--add-tag=mvai-online-training` — never any other tag, never modifying SEV state, never resolving.
- If any `meta sevmanager.sev update` fails, log in message and continue. Do not retry.
- If 0a query fails entirely, fall back to Cat 1 only and note degradation.
- Cap 15 total items per message.
- Cat 1 + Cat 0-A overlap: apply once, credit to whichever fired first (Cat 0-A typically).

## Learned Rules (auto-appended)

4. [2026-05-05 operator feedback] (a) SEV view URLs are noise — GChat auto-linkifies bare `S<num>`. URL pre-fetch step removed. (b) SEVs in each section must be ordered: In Progress > Mitigated > Closed; then L1>L2>L3>L4; then sev_id desc. (c) Cat 0-B was surfacing obvious OT SEVs (S658165 "IG OT jobs crashing on model publishing", S657606 "threads feed u2m online training blocked") because regex required `online[._-]?train` separator and lacked `OT jobs` token. Both extended; principle codified: any literal OT phrase in title ("online training", "OT jobs", "OT stream", `mvai-training-online-`) auto-promotes to Sub-A.
3. [2026-04-29 15:38 PT manual live-test, iteration 2] sev_type=Production alone is too narrow — S652695 (Threads Feed LSR online training, real OT SEV) is sev_type=Instagram. Gate widened to {Production, Instagram}. Tightened `publish` to `publish(?!er)` to exclude Ads S652258.

2. [2026-04-29 15:35 PT manual live-test] Title-only regex over whole SEV manager produces false positives for cross-product ML systems sharing keywords (Ads `mtml`, `snapshot`, `publisher_features`). Gate Cat 0-A and Cat 0-B on `sev_type=Production`. Bumped `--limit` from 100/200 to 300 — live test missed S654315 (canonical OT SEV, mvai/mvai_ifr_main TGIF publish failure) outside 100-cap. S654315 manually tagged 2026-04-29 15:35 PT.

1. [2026-04-29 manual] Every OT SEV should carry `mvai-online-training`. Cat 0 broad sweep enforces autonomously for high-confidence cases; proposes for heuristic matches. Sourced 2026-04-29 15:26 PT.
