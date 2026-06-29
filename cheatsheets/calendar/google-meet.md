# Calendar: Creating Meetings with Zoom + AI Meeting Notes

**Last verified:** 2026-05-07 (Pylon, after `--google-meet` script bug AND missing AI summary on the team-debug-agent meeting)

## TL;DR

**Use `meta calendar.meeting create --ai-summary`** for every meeting. It's a single command — adds Zoom and AI meeting notes (transcription + summary) in one shot. Don't use the calendar skill's `create-meeting.py` script; it's broken on `--google-meet` and has no AI-summary support.

## Boss's default rules (apply unless explicitly overridden)

### VC + AI rules

1. **VC (Zoom) ON for every scheduled meeting.** Even attendees who plan to be in-person need a join link as fallback (sick day, travel, room reshuffle, partner-team join). The only meetings without VC are solo focus blocks. **Never schedule a meeting without VC** unless boss says "in-person only" or "no VC."
2. **AI meeting notes ON for every meeting.** Auto-transcript + summary land in the meeting record post-event, which is load-bearing for boss's catch-up workflow.
3. Both rules above are satisfied by a single flag: **`--ai-summary`** (auto-enables Zoom).

### Scheduling rules

4. **Avoid Fridays.** Don't schedule meetings on Fridays unless boss explicitly asks for one. When picking slots from a candidate set, drop all Friday options first; if only Fridays remain, surface that to boss before booking instead of defaulting to one. Recurring weekly series should not land on Fridays.

## Primary path — single command

```bash
START_TS=$(date -d "2026-MM-DD HH:MM PT" +%s)
meta calendar.meeting create \
  --subject "<title>" \
  --start "$START_TS" \
  --duration 30 \
  --attendees "user1@meta.com,user2@meta.com,user3@meta.com" \
  --body "<short context / agenda>" \
  --ai-summary
```

Returns the meeting ID, Zoom link, and event URL. Done.

### Flag rules of thumb

| Flag | When to use |
|------|-------------|
| `--ai-summary` | **Always** unless boss says no. Auto-enables Zoom (covers both default rules in one flag) |
| `--zoom` | Redundant with `--ai-summary` (auto-enabled). Specify only when AI summary is explicitly off but VC is still needed (rare) |
| `--no-zoom` | **Only** for solo focus blocks. Never for any meeting with attendees. If boss asks for "in-person only" — confirm before applying |
| `--meeting-buffer` | Use when scheduling back-to-back; starts 5 min late |
| `--optional-attendees` | For attendees who can skip (e.g. broad notification list) |
| `--on-behalf-of <email>` | Creating in someone else's calendar (delegate access required) |
| `--recurrence=weekly --recurrence-days=MON,WED,FRI --recurrence-end-date=YYYY-MM-DD` | For recurring series |
| `--dry-run` | Preview what would be created — no commit |

### Time format gotcha

`--start` takes **Unix timestamp** (not ISO). Convert via:

```bash
date -d "2026-05-13 09:30 PT" +%s
# → 1778517000
```

Always specify timezone in the input string or shell `TZ=America/Los_Angeles`. Skipping the timezone uses the host's default which is usually right but worth being explicit.

## Fixing an existing meeting (retroactive enable)

If a meeting was created without AI notes and/or Zoom, fix it without recreating:

```bash
# Need the meeting ID — see "Get meeting ID" below
meta calendar.meeting update \
  --id "GCAL:dennyzhang@meta.com:dennyzhang@meta.com:<event_id>" \
  --ai-summary
```

`--ai-summary` on `update` adds Zoom AND AI summary together (same auto-enable as on `create`). If Zoom is already attached, it just flips the AI flag.

## Get meeting ID

The meeting ID format is:

```
GCAL:<organizer_email>:<organizer_email>:<event_id>
```

Where `<event_id>` is decoded from the `eid=` query param in the calendar event URL.

```bash
EID="<base64-blob-from-url>"
EVENT_ID=$(python3 -c "
import base64
e = '$EID'
# Google strips base64 padding — re-pad before decoding
e_padded = e + '=' * (-len(e) % 4)
print(base64.b64decode(e_padded).decode().split(' ')[0])
")
echo "GCAL:dennyzhang@meta.com:dennyzhang@meta.com:${EVENT_ID}"
```

**Padding gotcha:** Without re-padding, `base64.b64decode` raises `Incorrect padding` AND falls through to an empty `event_id` that produces `Meeting not found`. Always re-pad.

## Recurring meeting example

```bash
START_TS=$(date -d "2026-05-13 09:30 PT" +%s)
meta calendar.meeting create \
  --subject "Team Debug Agent — weekly sync" \
  --start "$START_TS" \
  --duration 30 \
  --attendees "masa@meta.com,peiyangy@meta.com,lupaul@meta.com" \
  --recurrence=weekly \
  --recurrence-days=WED \
  --recurrence-end-date=2026-08-31 \
  --ai-summary
```

## What NOT to use

### `meta google.meet create` + `meta google.calendar.event create` — NEVER use this combo

**This was the mistake made on 2026-06-23 when scheduling a 1:1 with Wanli Ma.**

Don't create a Meet/Zoom link separately and then attach it to a calendar event manually. The `meta google.meet create` command creates a Google Meet link (wrong VC provider) and `meta zoom.meeting create` + `meta google.calendar.event create` as separate steps requires manual link insertion and has no AI notes.

**Always use `meta calendar.meeting create --ai-summary`** — one command, Zoom auto-enabled, AI notes enabled.

### `~/.claude/skills/calendar/scripts/create-meeting.py` — avoid

The shell script wrapped around `google-mux`. Two problems:

1. **`--google-meet` flag is broken** — passes `--conference-data-version` to `google-mux calendar create` which doesn't accept it. Fails with "unexpected argument".
2. **No `--ai-summary` flag** — has no way to enable AI meeting notes. You'd have to do a 2-step (`create` then `update --ai-summary`), which defeats the point of using the script.

The only thing the script offers over `meta calendar.meeting create` is unixname auto-resolution (`--with masa,peiyangy` → `masa@meta.com,peiyangy@meta.com`). That's trivial to do inline:

```bash
ATTENDEES=$(echo "masa,peiyangy,lupaul" | sed 's/,/@meta.com,/g; s/$/@meta.com/')
meta calendar.meeting create --attendees "$ATTENDEES" ...
```

### `--zoom` (alone) on an AI-summary meeting — redundant

`--ai-summary` auto-enables Zoom. Adding `--zoom` is harmless but cluttering. Just use `--ai-summary`.

### Google Meet — generally not worth it

`meta calendar.meeting` has no Google Meet flag. Zoom is the practical default for Meta-internal team meetings. If user explicitly insists on Google Meet, have them add it manually from the calendar UI after creation, or file friction.

## When to file friction

If `--ai-summary` stops auto-enabling Zoom (re-verify by running with `--dry-run`), or if `meta calendar.meeting create` regresses, file via:

```bash
meta ai.friction report \
  --summary="<one-line what broke>" \
  --tool="meta calendar.meeting create" \
  --description="<exact command and error>"
```

The `create-meeting.py` script's `--google-meet` brokenness is also worth a friction report against the calendar skill maintainers — but the workaround (just use `meta calendar.meeting create --ai-summary`) is so much cleaner that it's not urgent.

## Reference

- `meta calendar.meeting create --help` — canonical flag list
- `meta calendar.meeting update --help` — for retroactive AI-summary / attendee changes
- Calendar skill: `/home/dennyzhang/.claude/skills/calendar/SKILL.md` (its 2-step Zoom workflow predates `--ai-summary` and is now obsolete for this purpose)
