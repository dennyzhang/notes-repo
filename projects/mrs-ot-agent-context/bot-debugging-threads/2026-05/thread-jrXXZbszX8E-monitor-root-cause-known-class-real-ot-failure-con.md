# Thread Summary: Link Validation + Thread Reply Discipline + Enforcement Hooks Committed

_Source: spaces/AAQAVOjYc80 thread `jrXXZbszX8E` · 16 messages · 2026-05-20_
_Summarized: 2026-05-21 00:41 PT · last-msg-time: 2026-05-20T23:31:00Z_

## What was discussed

Started with a MONITOR triage output for 878858380 (facebook_cfr_main_mtml, late-arriving NaN sub-alert from S665902 Conveyor regression). Denny flagged the alert link as invalid. Then gave generic feedback: always reply in-thread, always validate links. Bot committed these as Proposal F output-quality rules, then at Denny's request wrote them into `~/.myclaw-ot-bot/CLAUDE.md` candidates and committed an `auto-fixes/` directory with 15 concrete fix patches + enforcement hook design. End of thread: Denny questioned whether the notes repo push was completed; bot had stopped responding (no response to 23:24Z, 23:29Z, 23:31Z messages).

## Key decisions made

- (2026-05-20T22:56Z) Two standing output-quality rules from Denny:
  1. **Always reply in the correct chat thread** — don't post a reply as a top-level message
  2. **Always validate links before emitting** — broken links are a trust failure
- (2026-05-20T22:59Z) These rules must be written into `~/.myclaw-ot-bot/CLAUDE.md` AND enforced via hooks (not just Proposal F prose)
- (2026-05-20T23:08Z) Bot committed `auto-fixes/2026-05-20/` with 15 patches (01–15) + enforcement hook design (`16-enforcement-hooks-design.md`): pre-emit linter with 10 rules in 4 categories (LINK/THREAD/CITE/FAMILY), phased rollout. Phase 1 = L-LINK-01 (alert URL truncation)
- **END STATE ISSUE**: Bot stopped responding after 23:08Z commit. Denny's 23:24Z ("are we done with the push?"), 23:29Z ("not pushed to notes repo"), 23:31Z ("why no response?") received no reply. Push to notes repo was NOT confirmed completed in this thread.

## Files / artifacts touched

| path | what changed |
|---|---|
| `auto-fixes/README.md` | NEW — auto-fix workflow + status legend |
| `auto-fixes/FIX-TEMPLATE.md` | NEW — fix patch schema |
| `auto-fixes/2026-05-20/01..15` | NEW — 15 concrete fix patches |
| `auto-fixes/2026-05-20/16-enforcement-hooks-design.md` | NEW — pre-emit linter design, 10 rules |
| `IMPROVEMENT-PROPOSALS.md` | Proposal F: output-quality section (link validation, thread anchoring) |

## Cluster / pattern references

_(No CL-NNN cluster references directly applicable to the meta-discussion content of this thread)_

## Followup items (not yet done)

1. **Verify notes repo push completed** — bot did not respond to Denny's 23:24–23:31Z push status questions; push may still be wedged (Bundle2 server-side error known from earlier in session)
2. Apply enforcement hook design from auto-fixes/16 to actual cron/agent code

## Cross-refs

- SEVs discussed: S665902
- Related threads: `MQwOLaC3jLc` (earlier session where Proposal F commits were made)
