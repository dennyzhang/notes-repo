```yaml
fix_id: sev-chat-via-meta-cli
title: Use meta sevmanager.chat list to read SEV-specific gchat (works when bot lacks room membership)
status: 🟡 drafted
identified: 2026-05-20 thread I4j4Jpv9-4w (S661645 chat access)
target: team_bot/cron-jobs/ot-sev-monitor.md
section: SEV root cause derivation — chat access
impact: Restores access to operator-written RCA that lives in SEV chat
cost: ~5-line cron prompt amendment
```

## Gap

Bot can't read SEV-specific gchat rooms (e.g., AAQAERLoxMw for S661645, AAQAZlWotYI for S665478) via `meta url.load`. SEV chats contain canonical operator-written RCA that's invisible to the bot's standard triage path. **However**, `meta sevmanager.chat list --sev=<num>` works and returns the chat content as text — this CLI path bypasses the gchat-room-membership requirement.

## Patch

```
SEV CHAT ACCESS — USE meta sevmanager.chat list:

  When triaging a SEV, after pulling agent-feed:

  1. Pull SEV chat via meta CLI (not via gchat URL):
     meta sevmanager.chat list --sev=<num> -l 30 --no-truncate

     This works even when the bot is not a member of the SEV-specific
     gchat room. The CLI uses the SEV platform's API directly.

  2. Parse the chat for:
     - Operator-written RCA (look for cc-bot output, paste URLs, code-block
       analysis)
     - Affected models list (mvai-training-online-* URLs in first message)
     - Workaround attempts (what's been tried, what worked, what's pending)
     - ST oncall / cross-team escalations

  3. Treat operator-written chat content as CANONICAL (per 07-agent-feed-
     paste-url-grep.md priority order).

  4. If `meta sevmanager.chat list` returns "No chat messages found":
     - Either chat is genuinely empty (some SEVs don't have chat)
     - Or the SEV's chat is gated; flag as needs-human-review

NB: this replaces the prior pattern of trying `meta url.load lookup
--input='chat.google.com/...'` which fails for SEV-specific rooms.
```

## Triggering evidence

- 2026-05-20 thread I4j4Jpv9-4w — S661645 chat access via meta sevmanager.chat list worked; via gchat URL didn't. Found canonical operator RCA (Jiahao Luo's cc-bot analysis: ALLREDUCE barrier timeout from DPP slowness, NOT mixed-PG hang like S665464).

## Validation

- [ ] All SEV triages cite either meta sevmanager.chat list output OR explicit no-chat-content note
- [ ] Compare meta sevmanager.chat list coverage vs meta url.load for SEV rooms — chat CLI should succeed where URL fails

## Related

- `07-agent-feed-paste-url-grep.md` (RCA priority ordering)
- `auto-learnings/patterns/defenses.md` D-025 (the "bot needs gchat access" gap — this fix is a workaround)
