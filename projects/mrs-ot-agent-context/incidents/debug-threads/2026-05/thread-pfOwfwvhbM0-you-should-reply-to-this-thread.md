# Thread Summary: Bot gap analysis — 6 categories, green batch landed, open decisions

_Source: spaces/AAQAVOjYc80 thread `pfOwfwvhbM0` · 43 messages · 2026-05-21_
_Summarized: 2026-05-21 23:47 PT · last-msg-time: 2026-05-21T17:48:43Z_

## What was discussed

Operator redirected a top-level bot analysis into this thread. Bot presented a 6-category gap analysis of current bot health, then received "go" approval to land all low-risk (🟢) items. Subsequent messages covered: orphaned `learnings.md` in mrs-ot-agent-context, misplaced `state/` directory in a human-facing folder, orphaned catchup files written by ingestor crons with zero consumers. Thread ended with a 6-item decision table requiring operator input.

## Key decisions made

- `2026-05-21T16:31` — Operator approved "go" on all 🟢 items. Batch landed: bold+`code` mass-fix (19 cron prompts, 172 fixes); CL-017 class-label sync (REAL_OT_FAILURE → MODEL_SIDE_OOS); owner-precedence rule (job-owner > model-owner > oncall); TZ discipline (R-EV1); disk pre-check in state-writing crons; auditor self-heal whitelist for R-EV1 + R-XR3-class-label.
- `2026-05-21T16:43` — `mrs-ot-agent-context/learnings.md` identified as orphaned (no cron reads/writes it; canonical ledger is `~/.myclaw-ot-bot/spaces/.../learnings.md`). Decision: trash it.
- `2026-05-21T17:13` — Operator flagged `state/` directory should not live in mrs-ot-agent-context (human-facing folder should contain only human-relevant context, not machine state files). Also: these two feedbacks should be tracked in `human-input-generic/` rather than as one-offs.

## Files / artifacts touched

| path | what changed |
|---|---|
| `fbcode/pe_mrs_ml/mrs_ot_agent/` (19 cron prompts) | Bold+`code` mass-fix; commits `75032147`, `5fa0b86d`, `45f5c3e5` |
| `mrs-ot-agent-context/learnings.md` | Identified for trash (orphaned) |
| `mrs-ot-agent-context/human-input/knowledge/archive/2026-05-18-*` (5 files) | Identified as wasted-writes (zero consumers); preserved in archive/ |

## Cluster / pattern references

- [CL-017] — discussed re: class-label mislabel on Shampoo NaN (model-side); R18.1 partial falsifier landed this session

## Followup items (not yet done)

1. Source-of-truth pipeline: pick option a/b/c (bot rec: c — `landed_hash` lockfile). Owner: Denny.
2. Catchup ingestor crons: wire into session-start vs. shut down. Deadline: before Monday 09:00 PT. Owner: Denny.
3. R-VERDICT-STABILITY rule — awaiting "land it". Owner: Denny.
4. Full R-VC0 runtime scope gate — awaiting "land it". Owner: Denny.
5. P59/P60/P61 → `known-patterns.md` — awaiting "land it". Owner: Denny.
6. Family-aggregation logic in alert-monitor — awaiting "land it" (rec: behind env flag first week). Owner: Denny.

## Cross-refs

- SEVs discussed: S666068 (R-VC0 misfire)
- Related threads: `zNu-DFBjb4g` (MyClaw diff revert — connected to the empty-response apology issue)
