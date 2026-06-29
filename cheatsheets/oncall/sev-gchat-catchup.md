# SEV GChat Catch-Up — Reading Method

**Last verified:** 2026-05-07 (Pylon, after multiple SEV gchat reads in one session: S660546, S654315, S635390, others)

## Goal

When boss joins a hot SEV thread mid-flight (often hours into it), produce a **5-line catch-up** in under 60 seconds:

1. **What broke + who's impacted** (one line)
2. **State**: investigating / mitigated / closed (one line)
3. **Smoking gun**: the specific message that diagnosed it, with author + quote (one line)
4. **Active threads**: who's working on what *right now* (one or two lines)
5. **What boss should do**: confirm hypothesis / loop in someone / nothing / file a category fix (one line)

If you can't fit it in 5 lines, you didn't extract enough — go back and prune.

## Step 1: Dump the chat

```bash
SPACE=spaces/<SPACE_ID>     # extract from URL: chat.google.com/app/chat/<SPACE_ID>
LIMIT=100                   # 100 covers ~6h on a hot SEV; bump to 200 for multi-day SEVs

meta google.chat.message list -s "$SPACE" --limit "$LIMIT" -o json > /tmp/sev_chat.json
```

Use the JSON output, not the table — table truncates messages and loses sender metadata.

## Step 2: Parse + filter bot noise (Python one-liner)

```bash
python3 -c "
import json
with open('/tmp/sev_chat.json') as f:
    raw = f.read()
idx = raw.find('{\"shaman_alerts')
data = json.loads(raw[idx:])
msgs = data['data']
# Bot accounts (numeric sender IDs) — filter these or summarize separately
BOT_IDS = {'886676667858092'}  # SEV bot, ChirpBot, TaskCreeper share this account
for m in reversed(msgs):
    t = m.get('create_time','')[:16].replace('T',' ')
    s = m.get('sender_name','?')
    sid = m.get('sender','')
    text = m.get('text','').strip().replace('\n',' / ')
    prefix = '🤖' if sid in BOT_IDS else '  '
    print(f'{prefix} [{t}] {s}: {text[:500]}')
"
```

The `🤖` prefix lets you scan past bot noise visually. Don't drop bot messages entirely — they carry SEV renames, severity changes, file-a-task IDs, robodial events. Just downweight them on first read.

## Step 3: Extract the load-bearing artifacts

Scan once for these IDs and links — they're the structured spine of the SEV:

| Pattern | Why it matters |
|---------|----------------|
| `S\d{6}` | SEV ID(s). Multiple = related/dependent SEVs |
| `mvai-training-online-\d+` or `fire-*` | MAST job(s) under investigation |
| `D\d{6,9}` | Diffs that landed (mitigation) or are blamed (cause) |
| `T\d{6,9}` | Tasks filed via `#fileatask` |
| `https://fburl.com/canvas/...` or `https://fburl.com/scuba/...` | The chart that diagnosed it. Almost always the smoking gun |
| `https://fburl.com/logarithm/...` or `lg ...` snippets | Specific log lines that proved cause |
| Quoted log lines (e.g. `token queue size: 0`) | The actual evidence — usually buried mid-thread |

## Step 4: Bucket by author

Each named person in a SEV chat is investigating a different angle. Build a quick map:

```
Kedong He        — model owner; reporter; impact accounting
Michael Poggy    — DPP master logs; cross-checked Scribe SEV; found smoking gun
Yeehan Chen      — DPP oncall; chirped in
Rushi Gajaria    — DPP infra; corroborator
Denny Zhang      — coordinator; filed task; created SEV doc
```

This shows you *who* would respond to *what* question. If a finding is from Michael (DPP), and someone is asking about model NE (modeling concern), you know to ping Kedong.

## Step 5: Locate the diagnosis pivot

There's almost always one message that turns "we don't know" into "we know." Look for:

- A specific log line **quoted** (not paraphrased) — `Michael Poggy 20:35: I see "feed_learning_xsurface_training_data token queue size: 0"`
- A canvas/scuba link with comparison wording — "previously steady, now sporadic"
- A "this looks like X" claim from someone with subsystem authority (DPP person on a DPP issue, etc.)

That message is your **smoking gun** for the catch-up. Quote it verbatim. Without quoting, the catch-up loses authority — readers can't independently verify.

## Step 6: Identify stale pings

In the chat output, scan for `@<Person>` mentions and check if that person responded. Unresponded pings = open dependencies. Surface them in the catch-up if relevant.

## Step 7: Filter for decisions

Decisions are easy to miss because they're often hashtag bot interactions:

| Pattern | Decision captured |
|---------|------------------|
| `#fileatask` followed by `TaskCreeper: Filed T...` | A task was filed (note the ID) |
| `#fileadoc` followed by `Created and shared a Google Doc` | SEV doc exists (note the link) |
| `SEV renamed from X to Y` | Title changed → scope shifted |
| `#status_update` or `Robodialed` | Escalation event |
| `#chirp @Person` | Specific person was paged |

## Output format — the 5-line catch-up

```markdown
**SEV:** S660546 — Stale full snapshot in all HSTU retrieval prod, holdout and QE models
**State:** In Progress, escalated to dpp_master oncall (Yeehan Chen) at 20:25 PT 5/6
**Smoking gun:** Michael Poggy 20:35 PT — quoted log `feed_learning_xsurface_training_data token queue size: 0` on rank 0; Scribe write QPS chart [https://fburl.com/canvas/cnbf3fut] shows sporadic writes since today vs steady before. NOT in S660220 SEV1's affected categories list.
**Active:** DPP team confirming master-side; Rushi suggested pulling in category owner oncall; Kedong impacted-models spreadsheet [link]; T269898417 filed for OT debug agent improvement
**What you should do:** Decision on whether to loop in `feed_learning_xsurface_training_data` category owner now (Michael deferred to Yeehan for confirmation). Read Yeehan's reply when it lands.
```

This catches you up without re-reading 30 messages.

## Common antipatterns to avoid

| Don't | Why |
|-------|-----|
| Summarize bot messages as if they were findings | Bot output (SEV rename, file-a-task) is *decisions made*, not new evidence |
| Paraphrase log lines | Loses verifiability. Always quote literal text in monospace |
| List everyone who said anything | You want investigators with subsystem authority, not chorus |
| Treat the latest message as "current state" | Latest is often a question, not a status. State = last confirmed finding |
| Cite the SEV title verbatim if it was renamed | The current title may be misleading (originally a symptom, now a cause); call out the rename |

## Catch-up triggers — when to use this

- Boss types "read SEV gchat <url> and tell me what's going on"
- Boss joins a SEV space he wasn't in before
- A SEV-tagged thread has >20 messages and boss needs the state in <1 min
- Multiple parallel SEVs are referenced and boss needs the cross-reference map

## Companion

For the *response* side (what to do once caught up), see [oncall/sev.md](sev.md).
For SEV identification logic / SEV bot wiring, see `pe_mrs_ml/mrs_ot_agent/src/capabilities/sev_identification.py`.
