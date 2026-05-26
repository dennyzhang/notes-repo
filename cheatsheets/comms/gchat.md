# GChat Operations Cheatsheet

Operational rules for GChat — Claude sessions, MyClaw/MetaClaw daemons, and `cron-morning-gchat.sh`. For message tone and recipient playbook, see `gchat-coaching.md`.

## RULE #1 — Reply in the thread (always)

**Operator-set ground rule (2026-05-16, thread `iqRw-QgzYjM`):** *"only reply to thread, so the gchat space become less messy. dedicated discussions are aggregated by gchat threads."*

| Incoming message | Bot reply target |
|---|---|
| Top-level message in space | Top-level reply (default thread, per space config) |
| Reply inside thread `T` | **Same thread `T`** — never the main space |
| Operator replies in DIFFERENT thread to redirect you (e.g., `pFlYRGd0q2c` 2026-05-16 13:55) | Reply in THE THREAD OPERATOR JUST POSTED TO, not the topic-origin thread |

**Why:** dedicated discussions aggregate as threads. A reply landing top-level when the operator threaded splits one conversation into disconnected fragments — other members see a reply with no question; the operator sees a reply where they didn't ask one; threaded follow-ups land orphaned.

**How to verify before sending** (mechanical check):
1. Look at the `thread_name` field on the operator's most recent message.
2. If it ends in `/threads/<id>` → my reply MUST go to that thread.
3. If `thread_name=''` (empty string, not absent) → top-level is correct.
4. **When in doubt, thread.** Top-level reply when a thread existed = much higher cost than threaded reply when top-level was expected.

**Anti-pattern caught tonight (2026-05-16):** operator flagged this same mistake 3 times in one session (threads `pKP57GxypBo` 12:25, `pFlYRGd0q2c` 13:55, `iqRw-QgzYjM` 14:07). The discipline rule was already in this cheatsheet and in `~/.myclaw-ot-bot/RULES.md`; failing to *check* the thread_name field before sending is the recurring mistake. Pre-send `thread_name` lookup is the only reliable mechanism.

**Audit trail anchoring (2026-05-20):** When a cron posts a triage in thread X, ALL follow-ups (operator corrections, bot self-corrections, audit findings) must land in the SAME thread X. Cross-thread splits break the audit trail — someone reviewing the incident later can't reconstruct the conversation. If model_id in the bot reply doesn't match the triggering cron post's thread, it's a mismatch bug, not a threading choice.

**Implementation (Google Chat API):**
- Incoming message payload includes `thread.name = "spaces/SPACE_ID/threads/THREAD_ID"`
- Outgoing `messages.create` MUST set the same `thread.name`
- Alternative: `messageReplyOption: REPLY_MESSAGE_FALLBACK_TO_NEW_THREAD` when threading by `threadKey`
- Dropping `thread.name` posts to the main space → looks like the bot ignored the user's thread

## Send vs Read — who can do what

| Surface | Read | Send |
|---------|------|------|
| Claude session (this CLI) | YES — `gchat read/search`, MCP read tools | **NO** — hook-blocked (`gchat send/post`, `SendMessage`) |
| MyClaw daemon (`myclaw-*`) | YES | YES — replies to user messages in mapped space |
| MetaClaw daemon (`metaclaw-daemon`) | YES | YES — replies in `spaces/AAQAAlR6e34` |
| `cron-morning-gchat.sh` | — | YES — daily error summary to MetaClaw space, only on red days (no green-day spam) |

**Why:** GChat write APIs authenticate as Denny (or as the bot account that the daemon owns). A Claude session sending = Denny's name on a message Denny didn't write. Zero exceptions, no flag override.

## Thread discipline (daemon replies) — expanded patterns

## Read patterns

| Need | Tool |
|------|------|
| Recent messages, normal space | `gchat read --space spaces/X --limit N` |
| Large/discoverable space where `gchat read` returns empty | `gchat-big-space-read` skill (raw API with user-auth token) |
| Search across spaces | `gchat search --query "..."` |
| Cross-space scan, classify by priority | `metaclaw-gchat:gchat-triage` (every 30 min batch) |
| DM thread context | `gchat read` with the DM space ID — same shape as a group space |

## Write patterns (daemons + cron only)

| Pattern | Tool / Field |
|---|---|
| Reply in thread | `thread.name` in `messages.create` body |
| Reply with quoted message | `quotedMessageMetadata` block |
| Emoji react instead of reply (acknowledge) | `metaclaw-gchat:emoji-reactions` skill |
| Card / formatted block | `cardsV2` field |
| Avoid double-post on retry | Use `requestId` for idempotency |

## Common mistakes

| Wrong | Right | Why |
|---|---|---|
| `gchat send` from Claude session | Draft text in session output; Denny pastes | Hook-blocked. Authenticates as Denny. |
| Bot reply with no `thread.name` to a threaded user message | Echo `thread.name` from incoming payload | Splits thread, looks like bot ignored thread |
| Guessing unixname for `@-mention` | `gchat space members` or employee search first; never fabricate | Past incident: invented "huiminz" → wrong person tagged |
| `WebFetch` on chat.google.com / Workplace | Use `gchat` / `meta` CLI | Meta-internal domains always fail WebFetch |
| Cron posting to MetaClaw space on green days | Only send when unresolvable problems exist | No green-day spam in shared space |
| Bot replies in EVERY group chat message | Only when mentioned, adding value, or correcting misinfo | Quality > quantity (`system/myclaw.md` group chat rules) |

## References

- `system/myclaw.md` — three-instance model, session startup, heartbeats, group chat rules
- `comms/gchat-coaching.md` — message tone, recipient playbook (content, not transport)
- `scripts/cron-morning-gchat.sh` — only cron sender, gated on red days
- `feedback_never_guess_unixname.md` (memory) — resolve via space members first
- `gchat-big-space-read` skill — workaround for spaces where bot tokens lack read perm
