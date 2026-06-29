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

## Brevity discipline (every msg earns its line)

Default state is no-message. Every bot reply must earn its line in the operator's GChat — if unsure, don't send.

**3 anti-patterns to cut:**

1. **Status-during-work.** Don't post "🔁 Working on X, ETA 10 min" then "✓ done". Stay silent during work; post ONCE when done. Exception: work >15 min AND operator waiting on the specific deliverable → ONE brief "still on it, ETA N min" is OK.
2. **Post-action self-confirms on pre-authorized moves.** Don't post "✓ Shipped X" / "✓ Memory saved" / "✓ Sync verified" after pre-authorized reversible work. The action speaks for itself. Reserve ✓ for "you asked me to verify, here is the verification."
3. **Multi-section walls.** Default to ONE bullet + visual marker, not 3 paragraphs. Multi-step progressions (A → B → C of related fixes) should be ONE summary message, not 3 separate messages with full reasoning.

**Discipline rules:**

- Before sending: re-read draft. Cut every sentence that doesn't add new signal.
- Consolidate within-thread: if about to send msg #3 in same thread within 30 min, fold into the previous and edit instead.
- Lead with marker per § Visual marker vocabulary. Reserve scarcity.
- 1 line per per-thread reply when the response is "ack" or "✓ done"; expand only when judgment / data / disagreement requires it.

**Length cap heuristic:**

| Response type | Default cap |
|---|---|
| Ack / confirmation | 1 line |
| Routine status update | 2–3 lines |
| Triage finding | 1 paragraph (≤80 words) |
| Multi-finding report or adversarial review | bullets + markers; never multi-paragraph prose walls |
| "Explain what you did" answers | bullets per fix, ≤5 bullets, ≤15 words each |

Source: 2026-05-28 operator feedback — *"check the gchat messages in this space for today. there are too many msgs. are they all necessary and helpful?"* Audit: 24/105 bot msgs, ~30% verbose.

## Visual marker vocabulary (for scannability)

Operator scans 10+ summaries/threads per minute. Leading visual markers let the eye filter "what needs me" in <2 seconds. Buried prose ⚠️ inside a paragraph defeats the purpose — only **line-leading** markers work.

**Vocabulary (small + distinguishable — do NOT proliferate):**

| Marker | Meaning |
|---|---|
| ⚠️  | NEEDS-ATTENTION (operator should look — anomaly / risk / soft-fail) |
| 🚫  | BLOCKED / degraded tool / hard-fail (escalation-worthy) |
| 🛑  | HARD-STOP / safety refusal / would-violate-rule |
| ✓   | DONE / verified (post-action confirmation) |
| 🔁  | IN-PROGRESS / will-report-back (so operator knows you're not stuck) |
| ▶   | NEXT-STEP / current-action (for run traces) |

**Discipline rules:**

1. **Lead-with-marker.** Bullets start with the marker: `⚠️ X`, not `X ⚠️`. Eye scans the LEFT column.
2. **Reserve scarcity.** If every line gets ⚠️, none of them mean it. Default state is no-marker. One ⚠️ at the top of a 20-line message beats six scattered ⚠️s.
3. **✓ only after verification.** Not after "I intended to do it" or "I just submitted it" without checking.
4. **Don't reuse a marker mid-message with different meaning.** E.g., don't use ⚠️ for both "look at this" and "tool emitted a warning".
5. **Marker inflation is the trap after positive feedback.** Instinct is "use more". Discipline is the opposite: use FEWER but always at the right moments.

**Where to apply:** gchat replies (especially long multi-section), cron run summaries (ot-sev-monitor / ot-alert-monitor / ot-post-monitor / daily-brief / shift-summary), HEARTBEAT.md, ledger entries.

Source: 2026-05-28 operator positive feedback in MyClaw 1:1 — *"I like the way you use ⚠️, this makes things need my attention scannable."*

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

## Reading SEV war-room chat via GraphQL (fallback when meta-CLI ACL breaks)

The `meta google.chat.message list` CLI is ACL-gated and can break. For SEV war-room chats specifically, use GraphQL directly — it is ACL-proof.

**Exact working command (verified 2026-06-22):**
```
meta graphql.query execute --schema=intern \
  --query='{ sev_event_from_number(number: N) { id gchat_space_resource_id chat_messages(limit: 200) { title is_list_truncated messages { author { name } timestamp body } } } }'
```

**Gotchas learned the hard way:**
- `--schema=intern` is required (`facebook` schema returns "No such field" error)
- Field is `author { name }`, NOT `sender { name }`
- `chat_messages` requires a `limit` arg (omitting it gives a validation error)
- Nested field is `messages` (NOT `nodes`)
- `is_list_truncated: true` means more messages exist — increase limit (max tested: 200)
- This path works for SEV chats ONLY; general GChat spaces have no GraphQL message-body edge
