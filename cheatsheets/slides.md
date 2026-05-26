# Slides Cheatsheet

Building effective slide decks for internal presentations. Learned from editing the autolearn sharing deck (April 2026).

## Design Rules

- **Bullets, not paragraphs** — one idea per line. Dense text blocks kill scannability.
- **Lead with the hook** — slide 2 should be "why should I care" (impact metric, before/after). Explanation comes after.
- **One line per point** — if a bullet wraps to line 2, it's too long. Cut or split.
- **Numbers > adjectives** — "42 deep dives in 2 weeks" beats "many deep dives quickly."
- **Consistent visual pattern** — pick one format (bold heading + short description) and repeat every slide. Audiences shouldn't re-learn how to read each slide.
- **Max 5 bullets per slide** — more than that and nothing stands out. Split across slides.
- **White space is your friend** — cramming more text doesn't communicate more. It communicates less.
- **Visuals over text** — a system diagram, screenshot, or short video explains in 3 seconds what 5 bullets take 30 seconds to read. Default to visual; fall back to text only when the concept is too simple for a diagram.
- **One diagram per complex concept** — if a slide describes a workflow, pipeline, or architecture, it needs a diagram. Text-only workflow slides are a smell.
- **Screenshots > descriptions** — "the routine doc has meetings, coaching, and follow-ups" is weak. A screenshot of the actual output is undeniable proof.
- **Pre-recorded demos > live demos** — live demos risk failures, thinking pauses, and time overruns. Record the demo, edit out dead time, embed the video. Audience gets the same value with zero risk.

## Slide Structure Pattern

Works well for dark-background tech decks:

```
[Green header — what this slide is about]
[White bold subheading — the key statement]
[Gray description — 1 sentence max]

> Bullet 1 — short, punchy
> Bullet 2 — one idea only
> Bullet 3 — a number if possible
```

Concrete example from the autolearn deck:
- Header: `THE KEY IDEA` (green, Space Grotesk)
- Subheading: `AutoLearn = Learn While You Sleep` (white, bold, 16pt)
- Description: 1 line in gray (12.69pt)
- Body: 5 green-bulleted lines in light gray (13.77pt)

## Content Lessons (from autolearn deck edits)

- **"Underselling" usually means wrong scope** — don't describe a feature by its smallest use case. "Meeting prep" undersells a system that automates all routine tasks. Name the full scope.
- **Pick examples that are hard to dismiss** — "42 deep dives in 2 weeks" with "4-8h topics → 25 min each" is concrete and verifiable. "Helped with research" is not.
- **Resolved items aren't challenges** — if you shipped it, move it to a "done" slide or cut it. Listing solved problems as open challenges undermines credibility.
- **If YOU don't understand a bullet, the audience won't** — "Builder Score 91+" meant nothing without context. If you can't explain it in 5 words, rewrite it.
- **Duplicate content across adjacent slides = confusion** — if slide 3 and slide 4 overlap, merge or differentiate clearly. Audiences assume each slide is new information.
- **Reframe "challenges" as forward-looking questions** — "Context loss across sessions" → "How does one person's AI knowledge scale to a team?" The question format invites discussion instead of sounding like a bug report.

## Anti-Patterns

| Anti-pattern | Fix |
|---|---|
| Paragraph block on a slide | Break into 3-5 bullet points |
| Bullet wraps 2+ lines | Shorten to one line or split into two bullets |
| Explanation before the hook | Move impact/metric slide to position 2 |
| Inconsistent formatting across slides | Pick one heading+body pattern, apply everywhere |
| Vague qualifiers ("significant", "major") | Replace with a specific number or cut the word |
| Too many slides for one concept | One concept = one slide. If you need 3 slides to explain it, simplify the concept |
| Reading slides aloud verbatim | Slides are scaffolding. Talk around them, don't narrate them |
| Listing solved problems as challenges | Cut resolved items — they undermine your credibility |
| Describing a tool by its smallest feature | Name the full scope, not the smallest use case |
| All-text slide for a workflow/pipeline | Add a system diagram — Excalidraw, Mermaid, or simple shapes |
| Describing output instead of showing it | Paste a screenshot of the actual output |
| Live demo in a short talk | Pre-record and embed — edit out dead time, zero risk |

## Checklist

- [ ] Slide 2 is the hook (impact, metric, "why care")
- [ ] Every slide passes the 3-second test — can you get the point in 3 seconds?
- [ ] No bullet wraps to a second line
- [ ] No slide has >5 bullets
- [ ] At least one hard number per key slide
- [ ] Consistent heading/body pattern across all slides
- [ ] No table-stakes statements ("AI is important") — cut or replace with specifics
- [ ] Total deck: 10-15 slides for a 15-min talk
- [ ] Final slide has a clear call to action or takeaway, not "Questions?"
- [ ] Every workflow/pipeline concept has a diagram (not just bullets)
- [ ] At least one screenshot of real output in the deck
- [ ] Demos are pre-recorded (not live) unless audience interaction is the point

## gslides CLI (Programmatic Editing)

Round-trip workflow:
1. `gslides edit <presentation_id>` — exports ghtml file
2. Edit the HTML file (text changes only)
3. `gslides apply <file>` — pushes changes back to Slides

### Key gotchas

- **Session clears after each apply.** Always re-export with `gslides edit` before making more edits. Stale exports → merge conflicts.
- **Bullet points:** Use `\n` within a single `<span>` text. gslides converts to multiple `<p>` tags on re-export, and they render correctly. Writing multiple `<p>` tags manually can lose content.
- **Structural changes (add/delete/reorder slides):** Cannot do via ghtml. Use `gslides slides delete` and other CLI commands.
- **Element IDs:** Each text block has a `data-element-id` (e.g., `p9_i6`). Target these for precise edits.
- **Style preservation:** Copy the exact `style` attribute from existing elements to keep fonts, colors, sizes consistent.

### Multi-paragraph elements (critical limitation)

Text blocks with multiple bullet points render as multi-`<p>` elements in the Slides API. These **cannot be updated via `gslides apply`** — the API's `deleteObject` fails because it doesn't recognize multi-paragraph text frames by their original element ID.

**Three workarounds, in order of preference:**

1. **`gslides content find-replace`** — best for simple text substitutions. No element scoping — it's presentation-wide, so the find text must be unique across all slides. If the same text appears on multiple slides, you'll get collateral damage.

2. **`gslides content batch-update` with raw API** — best for targeted edits when text isn't unique. Use `deleteText` + `insertText` with specific character indices:
   ```bash
   # First, get character indices:
   gslides slides get <id> <slide_id> 2>&1 | tail -n +2 | python3 -c "
   import json, sys
   data = json.load(sys.stdin)
   for elem in data['pageElements']:
       shape = elem.get('shape')
       if shape and 'text' in shape:
           for te in shape['text']['textElements']:
               print(elem['objectId'], te.get('startIndex',0), te.get('endIndex','?'),
                     repr(te.get('textRun',{}).get('content','')))"
   
   # Then, batch-update with deleteText/insertText:
   cat <<'EOF' | gslides content batch-update <id> --data -
   {"requests": [
     {"deleteText": {"objectId": "ELEM_ID", "textRange": {"type":"FIXED_RANGE","startIndex":N,"endIndex":M}}},
     {"insertText": {"objectId": "ELEM_ID", "insertionIndex": N, "text": "new text"}}
   ]}
   EOF
   ```

3. **`gslides apply`** — only works for single-`<p>` elements. Use for titles, subtitles, and other single-line text blocks.

**Split your approach:** Use `gslides apply` for single-`<p>` elements and find-replace or batch-update for multi-`<p>` elements in the same editing session.

### Page-scoped edits (critical for duplicated slides)

`find-replace` is presentation-wide by default. When you duplicate a slide and edit it, find-replace hits BOTH the original and the copy — causing collateral damage.

**Fix:** Use `batch-update` with `pageObjectIds` to scope to one slide:
```bash
cat > /tmp/fix.json << 'EOF'
[{"replaceAllText":{"containsText":{"text":"old","matchCase":true},"replaceText":"new","pageObjectIds":["SLIDE_ID"]}}]
EOF
cat /tmp/fix.json | gslides content batch-update <PRES> --data -
```

For full text replacement on a multi-paragraph element, use `deleteText` (ALL) + `insertText`:
```bash
cat > /tmp/fix.json << 'EOF'
[
  {"deleteText":{"objectId":"ELEM_ID","textRange":{"type":"ALL"}}},
  {"insertText":{"objectId":"ELEM_ID","insertionIndex":0,"text":"new line 1\nnew line 2\n"}}
]
EOF
cat /tmp/fix.json | gslides content batch-update <PRES> --data -
```

### Always re-export after structural changes

After `slides add`, `slides duplicate`, `slides move`, or `slides delete`, element IDs may change. Always run `gslides edit` again before text edits. Stale element IDs cause `deleteObject` 400 errors.

### Special characters in find-replace

Text containing `<`, `>`, or other special characters may cause `gslides content find-replace` to time out (exit 143). Use `batch-update` with raw API `deleteText`/`insertText` instead — it handles all characters reliably.

## Common Mistakes

| Wrong | Right | Why |
|-------|-------|-----|
| `gslides content find-replace --find "old" --replace "new"` | `gslides content find-replace <id> "old" "new"` | find-replace uses positional args, not --find/--replace flags |
| `gdocs insert-text` for HTML into doc tabs | `gdocs content insert-html <DOC> @file.html --tab-id <TAB>` | insert-text doesn't support tab-level HTML insertion |
| `cron_alert` vs `alert` in cron scripts | `cron_alert` | The function from cron-alert.sh is `cron_alert`, not `alert` |

## Key Insight

Slides are not documents. A document explains; a slide *reminds*. If the audience can understand the slide without you talking, you wrote a document and projected it. If they can't understand it at all without you, you wrote speaker notes and projected those. The sweet spot: the slide makes them curious, your voice satisfies the curiosity.
