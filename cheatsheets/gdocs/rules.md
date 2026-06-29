# Google Docs Cheatsheet

Quick reference for `gdocs` CLI operations. Load this before any Google Doc operation.

> **Meta-rule (operator request 2026-04-30):** ANY gdoc creation OR gdoc-tab creation must be followed immediately by a cheatsheet QA pass — verify comments preserved, set proportional column widths, set 11pt cell font, set `#C9DAF8` header bg, remove duplicate `<title>`-rendered paragraph, validate no `<pre>` damage. Hook (`~/work/claude/config/hooks/gdocs-post-verify.sh`) emits a MANDATORY reminder on creation events. Auto-memory entry `feedback_gdoc_creation_runs_cheatsheet.md` carries the canonical checklist for sessions that don't load this cheatsheet.

## ⛔ Universal Write Gate — READ BEFORE ANY DOC WRITE

**ALL writes use `gdocs` (`/usr/local/bin/gdocs`). NEVER `meta google.docs.<write>`.** This applies to text edits, structure edits, tab create/delete/rename, batch-update, replace, apply, insert-html, find-replace — every write path.

**Self-check: if you find yourself doing ANY of these, STOP — you grabbed the wrong binary, not a real wall.**

| You reached for... | Real answer |
|--------------------|-------------|
| `meta google.docs.tab.delete` / `.add` / `.rename` | `gdocs tabs delete` / `tabs create` / `tabs rename` (all accept `--untrusted-authors-mode`) |
| `meta google.docs.insert.html` / `.replace` / `.batch-update` / `.bulk-find-replace` / `.edit` | `gdocs content insert-html` / `gdocs replace --tab-id` / `gdocs batch-update` / `gdocs content find-replace` |
| `meta google.docs.apply` failing with missing `.base` sibling | `gdocs edit` → modify → `gdocs apply` (round-trip works under server-dispatch via gdocs) |
| `meta google.docs.copy` failing with "untrusted authors" at execution | `gdocs copy --untrusted-authors-mode` |
| `--local`, `--run-as-email`, `--auth-token-class`, `arc fix facts`, WWW On Demand setup | None of these. The wall is your binary choice. Switch to `gdocs`. |
| `meta google.docs.<write>` rejects `--untrusted-authors-mode` as an unknown flag | Confirms wrong binary. Only `meta google.docs` `get`/`export`/`list`/`apply`/`create`/`delete` accept the flag — and `apply` is broken under server-dispatch anyway. `gdocs` accepts the flag on EVERY subcommand. |

**Why:** `gdocs` is the Rust `google-mux` CLI; runs locally; reads `GOOGLE_MUX_UNTRUSTED_AUTHORS_MODE=1` from your shell or `--untrusted-authors-mode` on any subcommand. `meta google.docs.*` dispatches to a remote Hack sandbox that doesn't forward env vars and whose write subcommands either lack the flag or break on sibling-file staging. Docs with personal-gmail contributors (e.g. `denny.zhang001@gmail.com`, `SophiaZhang8709@gmail.com` in revision history) write fine via `gdocs` — they just refuse `meta google.docs.*` writes.

**Quick examples for common "blocked" tasks:**
- Merge tab A into tab B + delete tab A → `gdocs get <DOC> --untrusted-authors-mode` (extract A's body) → `gdocs content insert-html <DOC> --tab-id <B> --after-heading "..." --untrusted-authors-mode --file body-of-A.html` → `gdocs tabs delete <DOC> --tab-id <A> --untrusted-authors-mode`
- Tab rewrite on commentless tab → `gdocs replace <DOC> --tab-id <T> --from file.html --full-replace-removes-comments --untrusted-authors-mode`
- Round-trip edit → `gdocs edit <DOC> --untrusted-authors-mode` → modify → `gdocs apply <DOC> --untrusted-authors-mode`

(Learned 2026-05-17 + reaffirmed 2026-05-26 + 2026-05-26: three sessions hit the same wall by grabbing `meta google.docs.*` first. Cheatsheet rule existed at line 93 but was buried — hoisted to top-of-file. If you're about to declare a doc "unwritable", you're wrong.)

## Decision Tree — "I want to do X"

| I want to... | Use this | NOT this |
|-------------|----------|----------|
| **Read a doc** | `gdocs get <DOC>` (ghtml) | `--text` (loses formatting), `knowledge_load` (first tab only) |
| **Read a MULTI-TAB doc** | `gdocs get <DOC> --tab-id <ID>` (one tab) or `--expand-as-folder` (ALL tabs, one HTML each) | plain `gdocs get`/`--markdown` returns ONLY the **first tab** — silently misses other tabs. For rolling date-tab docs synced to context (e.g. `ot-ingest-gdocs`), plain `--markdown` tracks the top tab and goes **silently stale** if newest isn't kept at top (2026-06-24). List tabs: `gdocs docs tabs list <DOC>`. |
| **Change a word/phrase** | `gdocs content find-replace <DOC> "old" "new"` | `gdocs apply` (overkill, risks comments) |
| **Add a table row** | `batch-update insertTableRow` → re-fetch → `insertText` (3 steps) | One-shot batch (indices break) |
| **Update a full section** | `gdocs edit` → modify HTML → `gdocs apply` (round-trip) | `gdocs replace` (destroys comments) |
| **Sync tab content in cron** | `gdocs replace --tab-id <TAB> --from file.html --full-replace-removes-comments` | `insert-text` (appends = duplicates) |
| **Add content after a heading** | `insert-text --as-html --after-heading "Name"` | `insert-text --index` (fragile) |
| **Make a link clickable** | `batch-update updateTextStyle` with `link.url` | `find-replace` alone (dead text) |
| **Create a doc from template** | `gdocs create --from file.html` → fix table widths → fix separators | Skip post-creation cleanup |
| **Read comments** | `gdocs comments list <DOC> --untrusted-authors-mode` | Without `--untrusted-authors-mode` |
| **Reply to a comment** | Check last reply first (see dedup rule below), then `gdocs comments reply <DOC> <ID> "[Claude] text"` | Without `[Claude]` prefix; without dedup check |
| **Update auto-generated doc WITH active comments** | `batch-update` for cell content + `find-replace` for text (ai-health-push.py pattern) | `gdocs replace` (destroys all comments) |
| **Update auto-generated doc WITHOUT comments** | `gdocs replace --tab-id t.0 --from file.md` (clean, reliable) | `insert-text` (creates empty headings, breaks formatting) |
| **Update accumulating doc (daily content)** | `insert-text --as-html --index 1` (prepend today, preserve history) | `gdocs replace` (destroys prior dates + comments) |
| **Rewrite a research/strategy doc** | `gdocs replace --full-replace-removes-comments` (clean structure every time) | Incremental `insert-text` (breaks heading hierarchy, creates artifacts) |

### Push Method Decision Tree

```
Does the doc have ANY comments (resolved or unresolved)?
├── YES (comments > 0) → ONLY these operations allowed:
│     ✅ gdocs content find-replace (changes text, preserves comments)
│     ✅ gdocs content insert-text (adds content, preserves comments)
│     ✅ gdocs batch-update with insertText/updateTextStyle/updateTableColumnProperties
│     ✅ gdocs comments reply (replying, never resolving)
│     ❌ gdocs replace → HARD BLOCKED by hook (exit 2)
│     ❌ gdocs apply → HARD BLOCKED by hook (exit 2)
│     ❌ deleteContentRange → HARD BLOCKED by hook (exit 2)
│
└── NO (comments = 0) → Any method allowed:
    ├── One-time rewrite? → gdocs replace from clean markdown
    ├── Accumulating doc? → insert-text --as-html --index 1
    └── Otherwise → gdocs edit → modify → apply
```

**POLICY: User's Google Doc comments must NEVER be deleted by any automated action.**
Enforced by: PreToolUse hook (SYNC, exit 2), gdocs-safe-write.sh (cron scripts), CLAUDE.md rule.

## Hard Rules (read first)

| Rule | Why |
|------|-----|
| **All docs must be scannable** | Scannability is a non-negotiable requirement for ALL docs — research, proposals, business plans, design docs. Before generating: (1) use tables instead of paragraph lists, (2) bold key terms and metrics, (3) break paragraphs >2 sentences into bullets, (4) competitive comparisons always as tables, (5) verify: "can I get the key message in 5 seconds of scanning?" If a section is a wall of text, it fails this rule. (Learned 2026-04-06: user flagged as key requirement for all research) |
| **Oncall shift summaries: ≤4 pages hard cap** | Shift summaries (OT, MRS, any oncall) must fit in ≤4 printed pages (~12KB ghtml body). The reader is the incoming oncall who scans for hand-off + open issues in ≤3 minutes. Over-budget = info-density failure, not just length. Before push: (a) `wc -c` on ghtml body ≤ 13000, (b) section count ≤ 6, (c) NO redundant "End of <date> summary" footer lines, NO "FYI" filler bullets, NO unsorted lists. If over: cut historical detail BEFORE current shift content, scope HIGH-TOUCH to current shift only, drop pre-shift timeline entries. (Learned 2026-05-28: operator flagged 6-page tab as "too long for a shift report"; ot-shift-summary cron's default output regularly exceeds budget.) |
| **Identifier linking (universal)** | Every `S###` (SEV), `D###` (diff), `W###` (Workplace post), `A###` (alert), `T###` (task), `f###` (FBLearner run), `m###` / `mvai-training-online-###` (MAST job / model id) rendered into a gdoc MUST be wrapped in `<a href>` on the BARE TOKEN ONLY (never wrap a URL on a date, section header, or surrounding sentence). NEVER emit a bare ID without a link. Pre-publish validation: regex-scan rendered ghtml for `/[SDWATf]\d{6,}\|mvai-training-online-\S+/` and assert each match is inside `<a href>`. Validate href resolves — for AGG alerts (A###), the bare `?alert_id=<numeric>` URL does NOT resolve; use `short_id` from `meta oncall.feed metadata --id=<numeric> -o json` instead. If an ID cannot be resolved, OMIT the row rather than emit a broken link (operator flagged broken `A2449443538836650` on 2026-05-28 thread `WR9DFGuQ3dU`). Standard URL templates: SEV = `https://www.internalfb.com/sevmanager/view/<numeric>`, diff = `https://www.internalfb.com/diff/D<num>`, task = `https://www.internalfb.com/T<num>`, alert = use `short_id`, WP post = `https://fb.workplace.com/groups/<group>/permalink/<id>/`. |
| **Never delete diagrams/images from docs** | Diagrams are high-value artifacts — clear and powerful visuals that took effort to create. When refreshing a doc, preserve all existing images. If a diagram is outdated, refresh it with an updated version — don't delete it. Before any `gdocs replace`, check for inline objects (images/drawings) with `get-structure` (look for `[image]`). If present, use round-trip edit instead of full replace, or extract image URIs from the backup and re-insert after replace. (Learned 2026-03-31: full replace wiped 3 design diagrams from autolearn doc) |
| **Never delete prior dates from multi-day docs** | Docs that accumulate daily content (routine, area monitor, OT triage, AI health dashboard) must PREPEND today's content, never replace the full doc. Prior dates are historical reference. When pushing today's content: (1) fetch existing doc, (2) extract prior date sections, (3) combine today + prior, (4) push combined. A full replace that wipes prior dates is data loss. (Learned 2026-04-02: AI observability doc lost all prior dates from full replace) |
| **Never use `gdocs replace` on docs with comments** | Destroys headings (converts to bullets), destroys person chips, **deletes ALL comments**. Use `batch-update` instead. **Exception**: `gdocs replace --tab-id <TAB> --from file.html --full-replace-removes-comments` is safe for automated tab sync (cron scripts) — individual tabs rarely have comments, and the flag explicitly acknowledges the tradeoff. Never use `replace` on the main body (tab 0) of a doc with comments. **Before ANY cron auto-push**: check comment count first. If comments > 0, use round-trip edit (`gdocs edit` → modify → `gdocs apply`) or batch-update instead. Never assume a doc has no comments — check every time. (Learned 2026-04-04: auto-push wiped 60+ comments from AI Health Dashboard) |
| **Never use `--text` for reading** | `gdocs get <DOC> --text` discards formatting, comments, hyperlink URLs. Always use bare `gdocs get <DOC>` (ghtml). |
| **Never use `gdocs content insert-markdown` for headings** | Same heading destruction bug as `replace` |
| **Never use separator lines (`───`) in Google Docs** | Ugly, wastes space. Headings provide visual separation. Strip `---` horizontal rules when generating from markdown. |
| **Use round-trip for updates, batch-update for tables** | `edit` → modify HTML → `apply` preserves comments and formatting. But `apply` **cannot** add/delete table rows, change column count, or change text length inside cells — always fails with HTTP 400 or "Invalid deletion range". Use `batch-update` for all table structural changes (see recipes below). |
| **To replace full doc content with headings** | Create a new doc with `gdocs create --from`, delete the old one |
| **Never resolve comments without user asking** | `comments resolve` is buggy. Resolving hides the comment. Only resolve when user explicitly says "resolve". For programmatic resolve: `google-mux api call POST` to Drive replies endpoint. |
| **Never comment on other people's docs** | API posts as Denny. Tell user what to comment instead. **Exception**: on docs Claude's automation generates (diff review, routine, brainstorming), reply to Denny's comments directly. |
| **Always prefix replies with `[Claude]`** | API posts as "Denny Zhang" — without prefix, no way to tell human from AI. |
| **Dedup before every comment reply** | Before posting ANY `[Claude]` reply, check live comment state: `gdocs comments list <DOC> --untrusted-authors-mode`, find the comment by ID, and verify the last reply is NOT already `[Claude]`. If it is, SKIP — another session already handled it. This prevents duplicate replies across cron, Claude Code, and MyClaw sessions. (Learned 2026-04-06: comment AAAB2cWGWwM got 3 identical [Claude] replies from 3 different sessions because no live dedup check existed) |
| **Quality gate before `gdocs create` / `gdocs apply`** | Hook-enforced. Gate must create `/tmp/claude-quality-gate-passed` or the hook blocks. |
| **Verify styles after every `gdocs apply`** | Round-trip apply bleeds adjacent inline styles. See "Style Verification" section below. Fix with `batch-update updateTextStyle` — do NOT re-apply (causes more leaks). |
| **URLs in tables must be clickable `<a>` links** | Plain text URLs in Google Docs tables are not clickable. Always wrap in `<a href="URL">URL</a>`. |
| **Tables: set column widths proportional to content density (do NOT just equal-split)** | The sparse-table smell = uniform `data-col-widths` (e.g. `175,175,175,175,175`) when content density differs sharply. A single-value column (a count, ✅/❌, rank, short date) must be NARROW; the prose column (Note/description) takes the remaining width. Giving a 1-digit column the same width as a prose column renders a **sparse, half-empty table** that wastes horizontal space and starves the text. Fix = explicit proportional `data-col-widths` (e.g. `130,70,70,70,400`), via a `config/GDOC-TABLE-WIDTHS.json` entry for that tab+table — NOT the default equal split. **Do NOT "fix" sparseness by collapsing the count columns into one cell** (`4/3/1`): for the routine-doc Influence scoreboard that is explicitly forbidden — `cron-power-coach.sh` has a post-render lint + auto-expander (Denny GROUP A fix, 2026-06-21) that REQUIRES the 5-column `Move \| ✅ Used \| 🎯 Landed \| ❌ Missed \| Note` form and fails the push on a compact cell. Sparse ≠ too-many-columns; sparse = wrong widths. (Learned 2026-06-27: that scoreboard rendered 3 single-digit columns at uniform 175px, starving Note — operator flagged "why sparse columns… recurring mistake, debug and add preventions".) |
| **Verify EVERY write immediately — API "OK" ≠ correct** | After every `batch-update` (especially `updateTextStyle` with links), re-read the doc via structure API and confirm: (1) the target text has the correct link, (2) adjacent text did NOT inherit the link. Link styling bleeds into neighboring elements silently — a link applied to "FULL_SNAPSHOT stuck 4+h" can bleed into the heading "5/21 Thu" above it. Never claim a fix is done without verifying. (Learned 2026-05-25: WP post hyperlinks bled into date headings and SEV text; "OK" API response hid the problem through 3 rounds of user feedback.) |
| **Visual-state verification is the ONLY proof of DONE** | After ANY gdoc write (replace / apply / batch-update / append), VERIFY the visible browser state — not the export-text dump. Two failure modes hide in `gdocs get --text`: (1) **native gdoc hyperlinks render as bare label text in export** — grepping `<a href` on the export returns 0 for clickable links and >0 for BROKEN links that never got HTML-to-hyperlink converted (opposite of intuition); (2) **raw `<a href>` in non-table contexts** (bullets, paragraphs, headings) passes through markdown converters as literal text, showing as ugly `<a href="...">label</a>` HTML soup in the browser even though it looks fine in export. **Verification method**: `meta google.docs structure --id=<doc> --tab-id=<tab> --output=json | jq '.. | objects | select(.textRun?) | select(.textRun.textStyle?.link?.url) | .textRun.content'` — each label that SHOULD be a hyperlink must appear in this output. Bare-label appearance = broken link. Apply this check before claiming any gdoc write is done. (Learned 2026-05-18: claimed 5/18 ot-shift-summary tab "87 SEV anchors" by grepping `<a href` on `--text` export — reality was 87 BROKEN inline-HTML strings rendering as raw `<a href=...>S###</a>` text outside table cells, because `replace --markdown` only converts `<a>` to native hyperlinks INSIDE table cells, not in bullets / paragraphs / headers. Operator caught it.) |
| **All tables must have compact proportional widths** | After creating or modifying ANY table, set `FIXED_WIDTH` on every column with `updateTableColumnProperties`. Short columns (#, Status) get ~25-72pt, long columns (Description, Content) get ~130-200pt. Default equal-width columns waste space and look sparse. This is mandatory, not optional. |
| **Body font is 11pt — general rule across all cron-generated docs** | All body content (tables, `NORMAL_TEXT` paragraphs, list items) must render at 11pt. Headings MUST follow Google Docs defaults: H1=20pt, H2=16pt, H3=14pt. Never set a flat heading size (e.g. 12pt) on the whole doc — it collapses the visual hierarchy. Rule applies to every cron script that writes Google Docs: area-monitor, ai-health, alert-sync, ot-support-triage, signal-to-action. When adding a new doc-writing path: (1) apply 11pt on table ranges AND non-heading `NORMAL_TEXT` ranges, (2) explicitly restore heading sizes (H1=20pt, H2=16pt, H3=14pt) via `updateTextStyle` after any full-doc font pass, (3) lint should expect 11pt body / default heading sizes. (Learned 2026-04-17: 11pt body rule set; updated 2026-04-18 after comment AAAB3t2qfuY — headings must stay at Google Docs defaults, not 18/14 or 12pt) |
| **Table font must be 11pt — never inherit heading size** | After ANY table insert (especially via `insertTable` or `insert-text --as-html`), set font size to 11pt on all table cells via `updateTextStyle`. Tables near headings inherit the heading font size (14pt-20pt), making cells oversized and ugly. This is the #1 recurring table formatting complaint. Apply 11pt IMMEDIATELY after creating any table — do not wait for a separate formatting pass. (Learned 2026-04-06: user flagged as repeated issue; size bumped 10→11pt on 2026-04-17) |
| **NEVER push markdown content into tabs that contain headings + emojis** | Markdown → ghtml import (via `gdocs replace --from file.md`, `gdocs ... --markdown`, or `meta google.docs ... --markdown`) wraps EVERY heading in `<span style="font-size: 11pt">`. That span overrides H1/H2/H3 defaults — headings render at body-text size (invisible hierarchy). Worse: emojis at the start of headings get split across the 11pt span boundary, breaking the UTF-16 surrogate pair so the emoji renders as literal `??` in the doc. Damage is invisible until a human looks at the rendered doc — by which point multiple tabs are polluted. **Rules:** (1) always author tab content as ghtml (`<h1>`, `<h2>`, `<p>`, `<ul>`, `<table>`) and push via ghtml file (`.html` extension); (2) NEVER use markdown for content containing headings, emoji, or colored cells; (3) after ANY bulk write/import, MANDATORY heading lint: `meta google.docs get --id=<DOC> --tab-id=<TAB> --format=ghtml \| grep -cE '<h[1-6][^>]*>.*<span style="font-size:'` — output must be `0`. **Fix recipe** (font-size span pollution): get each broken heading's range, then `batch-update` with `{"updateTextStyle":{"range":{"startIndex":S,"endIndex":E,"tabId":"<TAB>"},"textStyle":{},"fields":"fontSize"}}` — empty textStyle + fields=fontSize clears the override so the heading inherits its paragraph style default. **Fix recipe** (literal `??` from split surrogate): `batch-update` `deleteContentRange` of the 2 `?` chars + `insertText` of the correct emoji at the same index, then re-clear fontSize on the new emoji char. (Learned 2026-05-20: ATTACK + R3++ + Reference tabs of Frontier AI Infra Interview Prep doc — 23 broken headings across 3 tabs from earlier markdown imports; user caught visual damage when reviewing ATTACK tab P1/P2/P3 section headings rendered tiny and emoji-mangled) |
| **Dashboard tables must sort rows by status severity** | When a table has a Status column (GREEN/YELLOW/RED), sort rows so RED appears first, then YELLOW, then other (TRACKING/N/A), then GREEN. Users scan top-down — critical items must be at the top. In awk: split on `\|`, use `$(NF-1)` not `$NF` for the status field (markdown table lines end with `\|` so `$NF` is empty). (Learned 2026-04-01: sort was broken because awk read the empty trailing field) |
| **Order sections by insight value, not alphabetically** | In multi-section docs (dashboards, reports), put insightful/actionable sections before stable/routine ones. A section with 20+ GREEN items is low-signal — move it below sections with active YELLOW/RED problems or trends. Users scan top-down and should hit the most important content first. This is a general rule for ALL auto-generated docs. (Learned 2026-04-03: user asked why routine cron fleet came before insightful operational health) |
| **Default table header color: `#C9DAF8`** (light blue) | Use `background-color: #C9DAF8` for all table header rows (`<th>` or first `<tr>`). In batch-update, use RGB values `{"red":0.788,"green":0.855,"blue":0.973}`. Consistent headers across all docs. |
| **Post-creation cleanup after `gdocs create --from`** | `gdocs create --from` produces equal-width table columns and converts markdown `---` to separator lines. After EVERY `gdocs create --from`: (1) `find-replace` to remove `───` separators, (2) set proportional column widths on all tables with `updateTableColumnProperties`, (3) set `#C9DAF8` header background on all table header rows via `updateTableCellStyle`, (4) set 11pt Arial font on table content, restore default heading sizes H1=20pt H2=16pt H3=14pt, (5) delete empty `NORMAL_TEXT` lines, (6) verify with `get-structure`. Also use `--folder 102z_IY_chAnw1Su5-F_dIDfOpUW9s4rZ` to place in Claude Generated Docs folder. (Learned 2026-03-23, updated 2026-04-18: default heading sizes enforced) |
| **Provenance header on all auto-generated docs** | Every doc created or updated by cron/automation must have a provenance line immediately after the `<h1>` title: `<p><i>Generated by: <script-name> (frequency) | Source: ~/work/claude/scripts/<script> | Last updated: YYYY-MM-DD HH:MM PST</i></p>`. This tells the next reader (human or AI) where the content came from, how fresh it is, and which script to fix if something's wrong. Omit for manually-written docs. |
| **Diagrams must be images, never ASCII art** | When a doc needs a diagram (flowchart, architecture, data flow), generate it with Graphviz (`dot -Tpng -Gdpi=150 file.dot -o file.png`) and insert with `gdocs content insert-image <DOC> file.png --after-heading "Section" --width 400`. Never use ASCII art (`→`, `↓`, `└──`, monospace alignment). ASCII art renders as ugly monospace text in Google Docs. Graphviz is available on the machine (`/usr/bin/dot`). Use color-coded subgraph clusters, shaped nodes, and edge labels for clarity. |
| **Don't fight table operations — ask the user** | Moving tables, creating tables with insertTable + cell filling, and deleting tables with deleteContentRange all fail unpredictably. Cell index calculation is fragile (assumes 2-char boundaries but real tables vary). When a task requires structural table changes (move, create from data, resize), describe what needs to happen and let the user do it in the Google Docs UI. Claude handles text, headings, find-replace, and simple batch-update well. Tables are the user's job. (Learned 2026-03-24: 3 failed attempts to move a 6x3 comparison table) |
| **Table schema change = delete + recreate, never morph** | When changing a table's column count, headers, or row structure, NEVER try to update cells in-place or use find-replace to clear old content. In-place updates append new rows without removing old ones, creating a hybrid table. Broad find-replace hits cells in OTHER tables across the doc. Instead: (1) delete the old table via `deleteTableRow`/`deleteTableColumn` or `deleteContentRange`, (2) insert a fresh table via `insert-text --as-html`. One clean operation, not incremental patching. (Learned 2026-04-12: morphing 5-col Auto-Learn into 4-col AI Impact created 9×5 hybrid table + damaged 3 other tables via broad find-replace) |
| **No empty lines between sections or table rows** | Never insert blank paragraphs or empty lines between content. Blank lines make docs look sparse and waste vertical space. Google Docs already provides visual separation via headings and horizontal rules. When generating HTML, skip `<p></p>` or `<br>` spacers between sections. When checking for this: `grep -c '<p></p>'` should be 0. (Learned 2026-04-04: area monitor had excessive empty lines flagged by user) |
| **Table cell content must be concise (max ~80 chars per line)** | Long text in table cells is unreadable. If a cell needs more than ~80 chars, break into 2-3 short bullet points or shorten aggressively. Set column max widths via `updateTableColumnProperties` so content wraps predictably. The readable width budget per content column is ~130-200pt (~60-80 chars at 11pt). Content that overflows this budget must be shortened, not just wrapped. (Learned 2026-04-04: area monitor table columns too wide, flagged as general cheatsheet rule) |
| **Examine table readability before pushing** | Before any auto-push to a Google Doc, verify: (1) no column is disproportionately wide for its content (e.g., "Pass Rate" column doesn't need 175pt), (2) all columns have proportional widths matching their content length, (3) numeric columns (%, counts, dates) get narrow widths (40-60pt), text columns get wider (150-290pt). This is a pre-push checklist, not optional. Run `get-structure` after push and verify no table has equal-width columns. (Learned 2026-04-05: recurring complaint about column widths) |
| **Post-push formatting checklist (mandatory for ALL cron scripts)** | After ANY push to a Google Doc (`gdocs replace`, `insert-text --as-html`, `gdocs create --from`), run this checklist: (1) Set proportional column widths on ALL tables via `updateTableColumnProperties` — never leave equal-width defaults. (2) Set table cell font to 11pt via `updateTextStyle` — `insert-text` inherits heading font sizes. (3) Restore default heading sizes (H1=20pt, H2=16pt, H3=14pt) if `format-text` or a full-range `updateTextStyle` was applied. Never use a flat heading size (e.g. 12pt) — follow Google Docs defaults. (4) Remove empty H1 headings — `insert-text --as-html` creates empty `<h1></h1>` artifacts between sections. (5) Verify with `get-structure` — no equal-width tables, no empty headings. This applies to EVERY doc-generating script: ai-health, nightly-routine, area-monitor, ot-support-triage, alert-sync. (Learned 2026-04-05; updated 2026-04-18: heading sizes set to Google Docs defaults, not 18/14pt) |
| **Regenerate today's content after 2+ workflow improvements** | After making 2+ changes to a cron-generated gdoc's script/template/config in the same session, ALWAYS regenerate today's content before declaring done. Don't ship and wait for tomorrow's cron. Steps: (1) delete today's entry from the tab (deleteTableRow bottom-up if tables present, then deleteContentRange for remaining text), (2) clear the script's state file if present, (3) re-run with `TODAY=YYYY-MM-DD DOW_NAME=... bash ~/work/claude/scripts/cron-<name>.sh`, (4) verify output structure + formatting. Applies to EVERY cron-generated gdoc: signal-to-action, area-monitor, ai-health, routine, ot-triage, alert-sync, ot-support-triage. (Learned 2026-04-17: same-session regen caught 3 bugs that would have quietly shipped: formatter missing today's table due to empty H2 artifact, LLM inventing timestamps instead of honoring placeholder, TODAY_FORMATTED ignoring env override for backfill) |
| **State today vs tomorrow explicitly when regen is comment-blocked** | When today's section has anchored user comments, `gdocs replace` and wholesale deletion are blocked (destroys anchors). Same-day regen then uses in-place cell updates — which refresh values but CANNOT change row count, row order, paragraph count, or heading structure. Any template change that adds paragraphs (e.g., a new Purpose block), sorts rows, or dedupes rows will only land on tomorrow's new-day prepend. Two actions required: (1) explicitly tell the user which fixes land today vs. tomorrow in the completion report, and (2) for the today-visible gap, manually close it with targeted ops: `insert-text --after-heading` for new paragraphs, batch-update cell swaps for row reorder, `deleteTableRow` for dedup. Never claim "Done" on a template change without closing today's gap or flagging it. (Learned 2026-04-17: AI Playbook regen — Purpose line, priority sort, and Stale-heartbeat dedup all had to be applied today via per-op surgery after in-place update couldn't reach them) |
| **No placeholder "Seen — will address next cycle" replies** | Never post a `[Claude] Seen — processing delayed. Will address in next cycle.` style placeholder reply to user comments. It creates false progress: a later real fix from another session leaves the placeholder permanently in the thread, and dedup across sessions becomes impossible. Instead: when the responder's LLM phase fails or a comment can't be addressed in the current cycle, write a single dashboard alert (e.g., via `cron_alert "<job-name>" "<N> comment(s) pending reply"`) so the backlog is visible as ONE signal on the AI Health Dashboard, not N noisy thread replies. The user sees "something's stuck" once, not once per comment. (Learned 2026-04-17: 3 "[Claude] Seen — will address in next cycle" replies from cron-gdoc-comments.sh fallback lingered behind real "[Claude] Done" replies from a later session, polluting every thread) |
| **No duplicate rows in generated tables** | Before emitting any table, check for duplicate rows. Common causes: (1) awk sort produces duplicate output when input has duplicates, (2) batch-update inserts into cells that already have content from a previous push, (3) "Total" summary rows that duplicate data from individual rows. Prevention: add `sort -u` after awk sort, or remove summary rows that repeat data already visible in per-source rows. (Learned 2026-04-05: Total row appeared twice in Metrics table) |
| **Post-synthesis D-number linkification (mandatory)** | When using LLM synthesis to generate markdown for Google Docs, always post-process the output to convert plain D-numbers to markdown links before md→ghtml conversion. LLMs frequently output bare `D12345678` even when explicitly prompted to link them. Regex: `re.sub(r'(?<![/>\w])D(\d{6,10})(?!\d)(?![^[]*\])', r'[D\1](https://www.internalfb.com/diff/D\1)', content)` — skips IDs already inside markdown links or URL paths. Apply this to ALL synthesis outputs (area monitor, routine, OT triage, AI health). A dead-text D-number in Google Docs is not clickable and not actionable. (Learned 2026-04-12: area monitor Team Activity had 20+ plain-text D-numbers despite prompt saying "NEVER plain text") |
| **LLM synthesis drops template structural elements** | When a prompt says "no boilerplate" or "keep content lean," LLMs interpret this as permission to drop template-provided structural elements like `> Source:` attribution lines, column headers, or provenance blocks. Fix: never use ambiguous "no boilerplate" instructions. Instead: "Keep all template structure exactly as-is (headings, source lines, column headers). Do NOT add extra structural elements beyond what the template provides." The same applies to column counts — LLMs will silently reduce a 3-column table to 2 columns if they don't have enough content for the third. Enforce column counts in the Rules section of the prompt, not just in the placeholder description. (Learned 2026-04-12: area monitor Org Pulse lost Source lines and Summary column across 7+ daily runs) |
| **LLM synthesis silently drops configured data sources** | When LLM synthesis processes data from multiple sources (workplace groups, peer lists, SEV feeds), it can silently drop ALL signals from a source if they don't meet a quality bar like "Would a director care?" Fix: add an explicit coverage instruction — "ALL configured data sources that have data MUST have at least one signal represented in the output." Without this, a configured source can be scanned, have real data, and still produce zero output for weeks without anyone noticing. (Learned 2026-04-12: MVAI FYI group was configured and returning 3 posts but never appeared in Org Pulse) |
| **Always use `gdocs` (standalone) for writes — never `meta google.docs.*`** | `gdocs` (`/usr/local/bin/gdocs`, the `google-mux` Rust CLI) and `meta google.docs.*` look interchangeable but are NOT. They go through different transports: `gdocs` reads `GOOGLE_MUX_UNTRUSTED_AUTHORS_MODE=1` from the local shell env directly; `meta google.docs.*` dispatches to a remote Hack sandbox that does NOT forward arbitrary env vars (only an allowlist of tracing vars). So `GOOGLE_MUX_UNTRUSTED_AUTHORS_MODE=1` set in bash works for `gdocs`, has zero effect on `meta google.docs.*`. Worse: write subcommands `meta google.docs.insert/edit/replace/bulk-find-replace/batch-update` do NOT have the `--untrusted-authors-mode` flag at all (only `get/export/list/apply/create/delete` do). `apply` has the flag but breaks under server-dispatch because the sibling `.base` snapshot file isn't staged across the sandbox boundary. Net: for ANY write to a doc with personal-gmail contributors (e.g. `denny.zhang001@gmail.com`), use `GOOGLE_MUX_UNTRUSTED_AUTHORS_MODE=1 gdocs content insert-html ... ` — never `meta google.docs.*`. The cheatsheet already standardizes on `gdocs` for this reason — don't drift to `meta google.docs.*` thinking it's a drop-in replacement. (Learned 2026-05-17: spent 40+ min trying `meta google.docs.insert html` + env var on R3++ deep-prep doc; only worked after pivoting to `gdocs`) |
| **`batch-update insertText` near a heading ALWAYS inherits heading style — fix immediately** | After EVERY `batch-update insertText` call where the insertion index is at or adjacent to a heading element, the inserted text inherits the heading's paragraph style (HEADING_2, HEADING_3, etc.) and renders at heading size. This is NOT visible in the API response — the call returns success, but the text displays huge in the browser. **Mandatory follow-up: immediately after every `insertText` near a heading, call `updateParagraphStyle` with `namedStyleType: NORMAL_TEXT` on the inserted range.** Pattern: `[{"updateParagraphStyle":{"range":{"startIndex":S,"endIndex":E,"tabId":"TAB"},"paragraphStyle":{"namedStyleType":"NORMAL_TEXT"},"fields":"namedStyleType"}}]`. Verify with `get-structure` — the element should show `NORMAL_TEXT`, not `HEADING_N`. This pattern was confirmed in 6 separate incidents in one session (2026-06-23): elastic agent paragraph, alert noise scenarios, Key Concepts Glossary, IG oncall text — all inherited HEADING_2 on first insert. |
| **Debug protocol: error names a flag/env var → grep the consumer FIRST, don't speculate workflow history** | When a CLI error message explicitly names an escape hatch ("set X" or "pass --Y"), the FIRST debugging step is to grep the codebase for the consumer of X/Y to understand which binary/path actually reads it. Do NOT skip this step and start theorizing about why a past invocation worked differently ("previous writes probably used `--local`..."). Plausible-sounding workflow stories invented from partial info burn cycles and mislead next session. Concretely: read the error verbatim → `grep -r "GOOGLE_MUX_UNTRUSTED_AUTHORS_MODE"` → find the binary that reads it → use THAT binary. The error itself is a pointer; treat it as load-bearing, not as a hint to be reinterpreted. (Learned 2026-05-17: told user "previous writes used `meta --local google.docs apply` workflow, then devserver phps broke" — fabricated explanation. Real answer: previous writes used `gdocs`, which still works; phps state is unrelated. User caught the speculation.) |

## Common Mistakes

Non-obvious pitfalls not covered by Hard Rules above. Grouped by operation type.

### Reading & Comments

| Wrong | Right | Why |
|-------|-------|-----|
| `gdocs content get-title <DOC>` | `gdocs get <DOC>` and parse the `<title>` tag, or `gdocs content get-structure <DOC>` and read the HEADING_1 | `get-title` is not a valid subcommand. The CLI suggests `get-structure` as the closest match. To get just the title: `gdocs get <DOC> \| grep '<title>'`. |
| `gdocs insert-text <DOC> @file.html --as-html` for HTML tab insertion | `gdocs content insert-html <DOC> @file.html --tab-id <TAB>` | `insert-text` does not support HTML insertion into tabs. `content insert-html` is the correct subcommand. (Learned 2026-04-14: cron-signal-to-action.sh first run failure) |
| `grep -q "$TODAY"` to check if today's entry exists in gdocs HTML | `grep -q "<h2.*$TODAY"` or `<h3.*$TODAY` | Bare date grep matches metadata timestamps, comment dates, and other non-content locations — causing false positive dedup. Use heading-level pattern to match only actual content entries. (Learned 2026-04-14) |
| `gdocs comments list <DOC>` without `--untrusted-authors-mode` | `gdocs comments list <DOC> --untrusted-authors-mode` | Same as `gdocs get` — fails on docs with external collaborators. Always include the flag. Note: `comments list` worked without it on some docs but fails unpredictably on others. Always include it. |
| Pulling all comments (including resolved) | Filter to unresolved-only before acting | Resolved comments are already handled — processing them wastes time and clutters output. In scripts: `not c.get('resolved', False)`. In interactive sessions: skip rows with RESOLVED=true. |
| Processing comments in one pass without re-checking | After addressing all comments, re-fetch `gdocs comments list` and compare against initial set. Process any new comments. | Users actively comment while Claude processes. Single-pass workflows miss comments created during processing. Always re-check at the end. (Learned 2026-03-24: missed 2 comments added during a 15-min processing window) |
| One-shot comment processing when `/my-finish comments` is invoked | Set up a 5-min polling cron per `/my-finish` Mode B instructions. Save baseline comment IDs, poll for new ones. | `/my-finish comments <URL>` triggers watch mode, not one-shot. The user expects continuous monitoring while they comment. Without polling, new comments go unnoticed until the user complains. (Learned 2026-03-24: missed 3 comment rounds because no cron was set up) |
| Moving/deleting table rows without verifying row numbers afterward | After ANY table row operation (move, delete, insert, swap), verify the # column is sequential. Fix numbering before replying. | Row operations silently break numbering. The user sees "1,2,3,4,5,6,8" and knows AI didn't check. (Learned 2026-03-24: moved OT Master to bottom, left # as 8 instead of 7) |
| Swapping row content via find-replace on non-unique text | Use batch-update with cell-level deleteContentRange + insertText in a single API call. Get exact cell indices first. | find-replace on common strings (e.g., "Open", "Mechanical enforcement") hits text in other sections. Batch-update with indices is O(1) API calls and positionally precise. (Learned 2026-03-24: "Mechanical enforcement" leaked into observations section) |
| Using `gdocs comments list` for polling/monitoring | Use raw API: `google-mux api call GET 'https://www.googleapis.com/drive/v3/files/<DOC>/comments?...'` with `fields=comments(id,content,resolved,createdTime,replies(...))`. MUST include `replies` in fields — user replies on existing comments are new instructions. | `gdocs comments list` CLI caches and omits newest comments. Also: polling only top-level comments misses REPLIES which are follow-up instructions. (Learned 2026-03-24: missed "change to 14%" reply on an existing comment) |
| Deleting/replacing text that has a comment anchored to it | Reply to the comment ONLY — never delete the anchored content | `find-replace` to empty string, `deleteContentRange`, or `gdocs apply` on anchored text destroys/orphans the comment. Before ANY content deletion, check `gdocs comments list` to see if comments are anchored to that text. If yes, leave the content alone and only reply. |
| `gdocs comments add <DOC> "note"` | Comment via Google Docs UI | `add` creates unanchored comments, invisible in UI |
| Resolving comments by replying (auto-resolve behavior) | Reply with `[Claude]` prefix, NEVER resolve. Let Denny resolve himself. | CLAUDE.md: "Don't resolve Google Doc comments — Denny resolves them himself." Some reply + edit sequences can cause comments to lose their anchors. The rule: reply only, never resolve, never delete content under a comment anchor. |
| Replying to a doc comment with "will do next session/cycle" instead of doing the work | Do the work immediately, then reply with what was done | Deferring to "next session" or "next cycle" is L8 (autonomy deficit). Default is act NOW — only defer if genuinely heavy (multi-hour research, cross-doc restructuring) or blocked (API down, missing info from user). Most comment requests are quick fixes. |
| Trusting prior `[Claude]` replies as proof that work was done | Before replying "already addressed," verify the CURRENT doc state with `get-structure` or `gdocs get`. | Prior sessions may have replied "[Claude] Done" but the change could have failed silently or been undone. Verify doc content before echoing "already addressed." (Learned 2026-03-24) |
| `gdocs batch-update \|\| true` on mutating commands (silent swallower) | `if ! echo "$json" \| gdocs batch-update ...; then echo "[ERROR] batch-update failed at \$0:\$LINENO" >&2; fi` | `\|\| true` suppresses failures — the script continues to format/verify steps against a doc that was never updated. Bug surfaces only when Denny looks at the doc. AI Health Dashboard greps logs for `[ERROR]` — tagged failures alert within minutes instead of hours. Enforced by `.git/hooks/pre-commit` (aborts commit if mutating `\|\| true` detected). Library helpers in `scripts/lib/gdocs_lib.sh` handle this automatically. (Learned 2026-04-18: swept 10+ sites across area-monitor, routine-preprocessing, ai-health, alert-sync, ot-support-triage, gchat-group-digest) |

### Tables

| Wrong | Right | Why |
|-------|-------|-----|
| Inline empty-line cleanup Python in each cron script | `source ~/work/claude/scripts/gdocs-cleanup-empty-lines.sh` then `gdocs_cleanup_empty_lines <DOC> [--tab-id <TAB>]` | Reusable script handles: (1) regex `(\S+?):?\s` to strip trailing colon from structure output type, (2) skips elements before TABLE (Google Docs requires a paragraph before tables), (3) downgrades empty HEADING_1/HEADING_2/HEADING_3 before tables to NORMAL_TEXT. Inline copies had a regex bug (`(\S+)` captures `NORMAL_TEXT:` with colon, never matching `== 'NORMAL_TEXT'`) that made ALL cleanup silently fail. (Learned 2026-04-12: 130 empty lines accumulated in routine doc) |
| `updateTextStyle` with table `endIndex` for font sizing | Use `endIndex - 1` | Table endIndex overlaps with the first character of the next element. Applying 11pt font to the full table range bleeds into the next heading, making the first character render at 11pt. (Learned 2026-04-12: 9 H3 headings had 11pt first character from table font sizing) |
| All table changes in one `batch-update` call | Split into multiple calls (insert row, re-fetch, then fill cells) | Batch updates are atomic — one failure rolls back ALL. Structural changes invalidate indices for subsequent content changes. |
| `gdocs content find-replace <DOC> "15 min" ""` | Use the most specific match string possible | Non-unique strings match ALL locations — tables, paragraphs, headings. |
| `find-replace` to append text (assumes plain formatting) | After `find-replace`, run `updateTextStyle` with `bold: false` on the inserted range | `find-replace` inherits formatting (bold, italic, font) from the character immediately before the insertion point. Appending to bold text produces bold output. Always normalize style after `find-replace`. |
| Using `<th>` tags in ghtml tables | Use `<td><b>header text</b></td>` | ghtml silently drops `<th>` content — renders as empty cells. Always use `<td>` with `<b>` for table headers. |
| **`meta google.docs.insert markdown` strips bold from table headers** | After EVERY `insert markdown` that contains a table: (1) `meta google.docs structure --tab-id <TAB>` to find each new TABLE element + its R0 cells (CELL elements with style starting `R0`), (2) for each header cell, `meta google.docs.format text --start <cell.startIndex> --end <cell.endIndex> --bold`. Tables in markdown use `| Header |` pipe-syntax which gets converted but the bold wrapper is dropped silently. This is the SAME class of bug as plain-text URL stripping after `insert markdown` — the converter renders content but loses inline formatting that markdown didn't explicitly tag. (Learned 2026-05-18: 21 header cells across 5 tables in MRS OT one-pager Tab 1 rendered as plain text after `insert markdown`; operator flagged via thread pQLWNSbGWO4 "why the table headers are not updated? the gdoc cheatsheet should instruct that".) Mandatory post-insert sweep: any `insert markdown` containing tables MUST be followed by header-bold pass. Same lifecycle as the URL linkifier sweep. |
| **`meta google.docs.insert markdown` strips plain-text URLs (no link wrapper)** | After EVERY `insert markdown`, sweep for unlinked URLs: use a regex helper to find `https?://...` and `fburl.com/...` substrings in elements without a `link` attribute, then `meta google.docs.format text --link=...` on each range. Same applies to D-numbers / S-numbers / T-numbers / W-numbers — the converter renders them as plain text. Use this regex set for the sweep: D=`(?<![\w/])D(\d{6,10})(?!\d)` → `internalfb.com/diff/D<num>`; S=`(?<![\w/])S(\d{6,7})(?!\d)` → `internalfb.com/sevmanager/view/<num>`; T=`(?<![\w/])T(\d{6,10})(?!\d)` → `internalfb.com/tasks/?t=<num>`; W=`(?<![\w/])W(\d{10,})(?!\d)` → `fb.workplace.com/permalink/<num>`. Same lifecycle rule as table-header-bold sweep: ALWAYS run both after `insert markdown`. (Learned 2026-05-18: operator flagged via thread `pQLWNSbGWO4`.) |
| `updateTableColumnProperties` with `"columnIndices":[0]` (array) | Pass scalar: `"columnIndices":0` (one request per column) | Despite Google Docs API docs declaring `columnIndices` as `integer[]`, meta CLI's PHP backend rejects array form with `"Starting an object on a scalar field"`. Always send a single integer per request — emit one `updateTableColumnProperties` per column. (Learned 2026-04-28: OT master agent design doc width pass) |
| Using `<pre>` tags in ghtml | Use `<code>` instead | ghtml does not support `<pre>` — content silently dropped. |
| ASCII art diagrams (`→ ↓ └── ───`) in docs | Generate PNG with `dot -Tpng -Gdpi=150 file.dot -o file.png`, insert with `gdocs content insert-image` | ASCII art looks terrible in Google Docs — monospace alignment breaks, arrows are unreadable, no color or shape distinction. Graphviz produces clean, color-coded, professional diagrams. Use `subgraph cluster_X` for grouping, `fillcolor` for categories, `shape="ellipse"` for terminals. This applies to ALL doc generation — design docs, research docs, area monitor, etc. (Learned 2026-03-31: autolearn doc had 3 ASCII diagrams, user asked why not images) |

### Content & Formatting

| Wrong | Right | Why |
|-------|-------|-----|
| Inline evidence/data in the key message | Move supporting evidence to a References section at the bottom | Content should focus on the key message. Evidence, calculations, and sourcing belong in References — readers scan the message first, verify data later. Inline data clutters the pitch and dilutes the point. This is a GENERAL RULE for all docs: proposals, research, business plans. (Learned 2026-04-06: "15-30% capacity loss, validated across 20 real SEVs" moved from Problem statement to References) |
| Plain text body without bold highlights | Use `<b>` on key terms, labels, metrics, and important phrases throughout doc body | Google Docs without bold looks flat and hard to scan. Bold the following in ALL generated docs: (1) labels like "Problem:", "Goal:", "How it works:", "Safety rails:", (2) key metrics and numbers like "3+ times", "20 rows", "10x cheaper", (3) important concepts like "OUTCOME-DRIVEN learning", "auto-fix", "closed loop", (4) decision names in first column of tables, (5) severity labels like "Critical", "BUILT". Don't over-bold — aim for 10-15% of body text. This makes docs scannable without reading every word. (Learned 2026-03-31: user flagged autolearn doc as missing bold emphasis) |
| Long text in `<td>` spanning multiple `<p>` tags | Keep cell content in a single `<td>text</td>` without inner `<p>` tags | Google Docs renders each `<p>` inside a `<td>` as a separate paragraph with line breaks, making the table look bloated. One cell = one line of text. **This is the #1 recurring table formatting complaint.** Before any table generation: validate that NO `<td>` contains `<p>`, `<br>`, or newlines. If content is too long for one line, shorten it — don't wrap. |
| Long single-line cell content (>80 chars) | Break into multiple short lines using `<br>` tags — one item per line. Semicolons are an escape hatch only. | Long paragraphs in table cells are unreadable. When generating table content: break every cell >80 chars into multiple lines (one fact per line). **Preferred**: `<td>Item 1<br>Item 2<br>Item 3</td>` — renders as distinct lines inside one cell. Only use semicolons if the LLM or pipeline can't emit `<br>`. This is a GENERAL RULE for all table generation — routine, alerts, signal-to-action, all docs. (Learned 2026-03-25: feedback repeated 4 times. Re-strengthened 2026-04-17: semicolon-separated ";"-megastrings demoted; line breaks are primary.) |
| Generating table rows where some cells are empty | Merge rows with empty content into adjacent rows | If a row has empty cells (no data for that column), don't emit the row — merge the content into the nearest non-empty row above or below. Empty rows waste vertical space and make tables look sparse. This applies to all generated tables (routine, alerts, quick wins, etc.). Before emitting any table: scan for rows where >50% of cells are empty and consolidate. |
| Table with overlapping or redundant rows | Deduplicate — each fact appears once | When a summary row contains per-item breakdowns in parentheses (e.g., "18 new (job-failures:8, audit-fail:8)"), don't also have separate rows for each item (e.g., "audit-fail: 8 this week"). One row per fact. Overlapping rows confuse readers who can't tell if counts are additive or redundant. Before emitting any table: check that no two rows present the same data at different granularities. (Learned 2026-04-03: autolearn Metrics had "This week: 18 (audit-fail:8)" + separate "audit-fail: 8" row) |
| Using `insert-text --as-html` to update tab content in cron/sync scripts | Use `gdocs replace --tab-id <TAB> --from file.html --full-replace-removes-comments` | `insert-text` APPENDS to existing content — every cron run stacks another copy, producing duplicate content. `replace --tab-id` does a full clear + replace. For any automated sync that runs on a schedule, ALWAYS use `replace`, never `insert-text`. (Learned 2026-03-29: people + project gdoc sync produced 3x duplicate content in every tab) |
| `gdocs replace --tab-id <TAB> --from full-doc.html` | Use a file containing ONLY the target tab's content | `replace --tab-id` with a multi-tab file dumps ALL content into the single target tab, destroying it. The file must contain only the target tab's `<article>` with matching `data-tab-id`, or a standalone `<body>` with just that tab's content. Also: the file's `<title>` overwrites the doc title — use the doc's real title, not the tab name. |
| Using `data-col-widths` in ghtml OR omitting widths entirely | Use `updateTableColumnProperties` via batch-update after inserting the table | `data-col-widths` creates equal fixed-width columns. Omitting it also creates equal-width columns across the full page. Both waste space in short-content columns. The correct approach: insert the table, then set proportional widths with batch-update `updateTableColumnProperties` (narrow for short columns like Risk/Action, wide for long columns like Review Comment). **This applies to `gdocs create --from` too** — tables in created docs always start with equal-width columns. After every `gdocs create` with tables, immediately run `updateTableColumnProperties` on each table. This is a mandatory post-creation step, not optional. |
| Editing `data-col-widths` in ghtml then `gdocs apply` to fix column widths | Use `batch-update updateTableColumnProperties` — `apply` IGNORES width changes | `gdocs apply` (ghtml round-trip) does NOT diff/apply `data-col-widths` changes — it reports `No effective changes to apply (content matches remote)` for width-only edits. Column widths are ONLY settable via batch-update. (Learned 2026-05-29: spent multiple apply round-trips on a #/Gap/Action table before realizing apply is a no-op for widths.) |
| `gdocs batch-update --data @file.json` for column widths | Pipe JSON via stdin: `cat cw.json \| gdocs batch-update <DOC> --data - --untrusted-authors-mode` | `--data @file` can mis-parse and hang on "reading from stdin" without applying. `--data -` with the JSON piped in works reliably and returns `{"replies":[{},{}...],"success":true}`. Empty `{}` replies = success for updateTableColumnProperties. (Learned 2026-05-29.) |
| For **gdocs** (Rust google-mux) batch-update, `columnIndices` | Array form `[0]` works (standard Google API) — scalar rule is meta-CLI-PHP only | The line above (scalar `columnIndices:0`) applies to `meta google.docs` PHP backend. `gdocs batch-update` sends raw Google API requests, so `"columnIndices":[0]` is correct. (Learned 2026-05-29.) |
| Setting widths on the wrong table; merge stripped widths → equal 175 | Get the index from `get-structure` and MATCH BY ROW COUNT (e.g. 8x3 vs 3x3), verify with `--no-cache` export | Two same-shape tables are easy to confuse — confirm `TABLE: RxC` row count, not just column count. ETag cache can show stale widths, so verify with `--no-cache`. Also: any merge/normalize that strips `data-col-widths` makes gdocs default to equal `175,175,...` → re-apply proportional widths via batch-update after every merge/insert. **Width readability rule: index/short columns (#, Status, dates) get ~40-60pt; content columns (Gap, Action, Description) get the bulk (~200-300pt). Equal widths make a narrow-content column look bloated while content columns are cramped.** (Learned 2026-05-29: merge into THIS WEEK stripped widths; #/Gap/Action rendered equal-width, col 1 too wide.) |
| `insertText` with tab-separated text near a heading | Use `insert-text --as-html` with a proper `<table>` element instead of tab characters | Tab-separated text inserted near a heading inherits HEADING_2 style — every line becomes a heading instead of table rows. Tab characters do NOT create tables in Google Docs. Always use HTML `<table><tr><td>` for tabular data. (Learned 2026-03-24: Cogwheel comparison section rendered as 7 HEADING_2 lines) |
| `insert-text --as-html` after a heading element | After insert, run `updateTextStyle` with `fontSize` 11pt on the inserted range | Inserted content inherits the paragraph style (font size, weight) of the surrounding element. Inserting after a HEADING_1 makes list items and table text render at heading size. Always normalize font after `insert-text --as-html` near headings. |
| Skipping style verification after `insert-text --as-html` or `gdocs apply` | Immediately run `gdocs content get-structure` and check for unexpected HEADING_2 entries where NORMAL_TEXT is expected | Heading inheritance is silent — you won't see it in the API response. The ONLY way to catch it is to verify structure after every write. If any line shows HEADING when it should be NORMAL_TEXT, fix with `updateParagraphStyle` to `NORMAL_TEXT`. This is a mechanical step, not optional. (AI Feedback Log L4: consistent error) |
| Using incremental `insert-text` to build up research/strategy docs | Use `gdocs replace` from clean markdown for full rewrites | Each `insert-text` inherits surrounding paragraph styles (body text becomes H2, headings become body text), creates empty H1 artifacts between sections, and inserts content in unpredictable positions. After 3+ inserts the doc is a formatting mess. For docs where you're iterating on content: regenerate full markdown and replace. Only use `insert-text` for accumulating docs (routine, triage) where history must be preserved. (Learned 2026-04-05: reliability moat doc needed 6 full rewrites to fix incremental insert damage) |
| Using `gdocs replace` without re-inserting diagrams | After ANY `gdocs replace`, re-insert images that existed before | `gdocs replace` wipes ALL inline images. They're not in the markdown — they were inserted separately via `insert-image`. Keep image file paths noted. After every replace: check pre-replace structure for `[image]`, re-insert each. (Learned 2026-04-05: architecture diagram lost on every replace) |
| Applying `format-text --font-size 11` to full doc range | Apply 11pt to table/body ranges only, then restore default heading sizes | `format-text` on full range sets EVERYTHING to 11pt — including headings. Headings become invisible. After any full-range format: run `updateTextStyle` to restore H1=20pt, H2=16pt, H3=14pt (Google Docs defaults). (Learned 2026-04-05; updated 2026-04-18: default sizes, not 18/14) |
| Using `deleteContentRange` or `gdocs apply` on ranges that contain comment anchors | Use `find-replace` to change text, or batch-update to modify specific indices — never delete ranges with comments | Deleting content that has comments anchored to it destroys/orphans the comments. Comments are tied to character ranges — when the range is deleted, the comment disappears from the doc. This is IRREVERSIBLE. Always check for comments before any delete operation. |
| `updateTextStyle` with empty `link` / `fields:"link"` to clear stray link styling on comment-anchored text | Use 2-step `replaceAllText`: (1) original line → unique placeholder, (2) placeholder → original line | When text was originally pasted from a comment-anchored span, the link styling is locked to the anchor and `updateTextStyle` cannot clear it. Replacing the text forces a re-render that inherits styling from the FIRST char of the matched text (typically unstyled), breaking the locked link span. Comments anchored elsewhere on the paragraph survive because the anchor is at character-range level, not span-style level. (Learned 2026-05-08: doc 1Zf3-P_fYdiGngU3qjYUGbEesQNnE1t1MifIIJipG-cY tab 0 had 3 stray wrong links on bullet text — updateTextStyle failed, 2-step replaceAllText cleared all 3 with all 19 anchored comments preserved) |

### Tabs & Automation

| Wrong | Right | Why |
|-------|-------|-----|
| Using `insert-text --as-html` to update tab content in cron/sync scripts | Use `gdocs replace --tab-id <TAB> --from file.html --full-replace-removes-comments` | `insert-text` APPENDS to existing content — every cron run stacks another copy, producing duplicate content. `replace --tab-id` does a full clear + replace. For any automated sync that runs on a schedule, ALWAYS use `replace`, never `insert-text`. (Learned 2026-03-29: people + project gdoc sync produced 3x duplicate content in every tab) |
| Inserting table row without verifying column order from header row | ALWAYS read header row (row 0) before inserting. Map data to column names, don't assume order from memory. | Column order varies per table. Guessing causes every cell to land in the wrong column. (Learned 2026-03-23) |
| `gdocs content find-replace` with em-dash (—) in bash string | Use `batch-update` with `replaceAllText` JSON, encoding em-dash as `\u2014` | Shell or gdocs CLI chokes on Unicode em-dash in bash strings — command hangs. (Learned 2026-03-23) |
| `gdocs comments reply ... 2>/dev/null` | Use `2>&1` instead of `2>/dev/null` | google-mux hangs when stderr is redirected to `/dev/null`. (Learned 2026-03-23) |
| Using `deleteContentRange` with pre-modification indices | Re-fetch `gdocs content get-structure` after ANY text change before index-based operations | After any text-modifying operation, document indices shift. Using stale indices deletes wrong content. (Learned 2026-03-23) |
| Multi-tab `batch-update` with `tabId` as CLI flag or top-level JSON field | Put `tabId` INSIDE the range object: `{"range": {"startIndex": 1, "endIndex": 5, "tabId": "t.abc123"}}` | Incorrect placement targets wrong tab or fails silently. (Learned 2026-03-23) |
| Using `find-replace` to create headings or structural elements | Use `batch-update` with `insertText` + `updateParagraphStyle` | `find-replace` can only change text within existing paragraphs. Cannot create headings, sections, or change paragraph styles. (Learned 2026-03-23) |
| `gdocs apply --ours` — panicking at the warning | Verify via Drive API before claiming damage. Warning is precautionary. | Verified: all comments kept `anchor=YES` after `--ours`. Still prefer `batch-update`, but `--ours` is a valid escape hatch on merge conflicts. (Learned 2026-03-23) |
| Rapid sequential `batch-update` calls (row-by-row table fill) | Use `gdocs insert-text --as-html` with a full `<table>` in one shot | google-mux hangs or corrupts data on rapid sequential batch-update calls. If hangs: `kill -9 $(pgrep -f google-mux); rm -f /tmp/gmux-dennyzhang.sock; sleep 5`. (Learned 2026-03-23) |
| `gdocs revision-content --format ghtml` | Use `--format txt` or `--format html` (ghtml not supported) | `revision-content` only supports txt and html formats. Convert manually for ghtml. (Learned 2026-03-22) |
| `gdocs replace --from file.txt` expecting txt format | `.html` extension is auto-detected as ghtml; `.txt` stays as txt | `gdocs replace` infers format from file extension. (Learned 2026-03-22) |
| Parsing text export table without understanding tab format | No-tab = first cell of row, tab-prefix = continuation cell in same row | Group cells by header column count to reconstruct rows from text export. (Learned 2026-03-22) |
| Using `\n` in `find-replace` replacement text to add line breaks | Use separate `find-replace` calls or `batch-update insertText` with actual newlines | `find-replace` treats `\n` as literal backslash-n, not a newline. The result is visible `\n` text in the doc. To add line breaks: either (1) split content into separate bullet items via round-trip edit, or (2) use `batch-update insertText` which accepts real newline characters. |
| Creating a Google Doc without adding it to the research overview table | After EVERY `gdocs create`, (1) use `--folder 102z_IY_chAnw1Su5-F_dIDfOpUW9s4rZ` to place it in the "Claude Generated Docs" Drive folder, and (2) add a row to the research overview table (1T7ai...). Applies to ALL doc types — research, planning, proposals, analysis. | The Drive folder is the single backup location for all Claude-created docs. The overview table is the index. A doc not in both is invisible. Folder ID also in `config/PROJECT-GDOC.json` as `gdrive_folder_id`. (Learned 2026-03-23, updated 2026-04-07) |
| Creating a research artifact without updating BOTH indexes | After EVERY research artifact (Google Doc OR local .md file): (1) add to `research-and-rampup-private/INDEX.md`, AND (2) add a row to the research overview Google Doc (1T7ai...). Both in the same pass — not "I'll do the other one later." | A research artifact not in both indexes is invisible. Repeatedly missed the Google Doc update until the user asked. The two-index update is ONE atomic step, not two. (Learned 2026-03-31: ally-building + personal context research both missed the overview doc. Folder renamed research-private → research-and-rampup-private 2026-04.) |
| Moving rows between tables in research index doc | The research index uses TWO tables: Active Research (queued/in-progress/applied/active/done-not-yet-archived) + Archive (archived reference). Rule (AAAB3XW72Ws, 2026-04-17): rows with status=`done` migrate to Archive same-session, not deferred. Row moves: (1) batch-update insertTableRow at end of Archive, (2) re-fetch structure, (3) batch-update insertText for each cell (#, Topic w/ link, Date, Summary), (4) batch-update deleteTableRow in Active bottom-up. If anchor text has resolved comments, move is still safe (threads already closed). Never defer with "next cycle" reply. | Old 4-table design (Critical/Applied/Reference/Done) caused constant move-between-table thrash — rebuilt to 1 table 2026-03-31. User then evolved to 2-table design (Active + Archive) for cleaner scan. Don't mark `done` rows as stale in Active — move them. Keeps Active table focused on what's actually in play. (Learned 2026-03-31 rebuilt to 1 table; revised 2026-04-17 to 2 tables with explicit archive migration rule) |
| `gdocs replace --from .html` strips `<a href>` links in table cells | After EVERY `gdocs replace` that contains tables with links: run `updateTextStyle` batch-update to re-add all links. The HTML renders text but drops hyperlinks. | Same mechanism as `find-replace` dead text. Links in `<a>` tags are silently discarded during the replace-from-HTML pipeline. Must follow up with explicit link styling via batch-update. (Learned 2026-03-31: 35 of 38 links lost on research index rebuild) |
| Creating a doc without stating the problem it solves | Every doc must have a "Problem:" line near the top explaining what problem it addresses. | Without motivation, future sessions can't understand why the doc exists. The problem statement is the first thing to read when reopening a doc. Format: `Problem: [what's broken/slow/missing without this doc].` (Learned 2026-03-24) |
| Using `knowledge_load` to read a multi-tab Google Doc | Use `gdocs tabs list <DOC>` then `gdocs get <DOC> --tab-id <ID>` | `knowledge_load` only returns the first tab. For any tab beyond the first, use the `gdocs` CLI with `--tab-id`. |
| Deleting a range that contains a table via `deleteContentRange` | OK when range **fully contains** the table(s) — no partial rows, no split cell boundaries. Batch multiple deletes in **reverse index order** (bottom-up) so earlier indices remain valid. Verify tab has zero `namedRanges` + zero `positionedObjects` in the range first. | Google Docs accepts deleteContentRange with embedded full tables. The `deleteTableRow`-first workaround is only needed when (a) the range splits a table partially, or (b) the range overlaps an anchored positioned object. Verified 2026-04-18 on OT Triage tab: 6 blocks with 3-4 tables each deleted cleanly, 33 comments preserved. |
| `gdocs get/export/replace <DOC>` without `--untrusted-authors-mode` | Always add `--untrusted-authors-mode` | Docs with external collaborators fail with "Access denied: resource has untrusted authors". The flag is required for any doc not exclusively authored by Meta employees. All cron scripts must include it. |
| `gdocs replace --from combined.html` with markdown content inside | Use `.md` extension for markdown, `.html` for ghtml — extension must match content | `gdocs replace` detects format by file extension — `.html` = ghtml (raw HTML), `.md` = markdown. Wrong extension means markdown syntax (`# heading`, `| table |`) renders as literal text instead of formatted headings and tables. |
| Fetching doc as `--markdown` then pushing back via `gdocs replace` | Fetch as ghtml (default), combine ghtml, push as `.html` | Markdown round-trip loses all formatting — headings become `# text`, tables become `\| pipe \|` text. ghtml preserves `<h1>`, `<table>`, `<b>` etc. Always stay in ghtml for read-modify-write cycles. |
| Assuming a stuck `gdocs` call is a network issue | Check `ps aux \| grep google-mux` for duplicate daemon instances | Two `google-mux daemon start` processes cause socket contention and indefinite timeouts. Fix: `pkill -9 -f "google-mux daemon" && rm -f /tmp/gmux-$USER.sock`, then retry (auto-restarts). Must remove stale socket — dead daemon leaves it behind and blocks new connections. |
| `dcat refresh` to fix daemon issues | `pkill -9 -f "google-mux daemon" && rm -f /tmp/gmux-$USER.sock` then retry | `dcat` may not be available. Killing the daemon AND removing the stale socket lets the next `gdocs` call auto-start a fresh one. |
| `google-mux chat spaces --limit 1` for health probes | Use `gdocs tabs list <DOC_ID>` and check for "TAB ID" in output | `--limit` is not a valid flag for `google-mux chat spaces`. The `gdocs` CLI with output captured to a variable is the reliable probe. Pipes/redirects to `/dev/null` can hang. |
| `gdocs apply --ours` on a doc with comments — panicking | Verify anchors before assuming damage: `google-mux api call GET` the comments endpoint and check `anchor` field | `--ours` triggers a warning about orphaning comment anchors, but in practice anchors survived intact (tested 2026-03-22: 8 comments, all kept `anchor=YES`). The warning is precautionary, not a guarantee of damage. Still prefer re-exporting cleanly or `batch-update` when possible, but `--ours` is not catastrophic. |
| Using `find-replace` to add new sections (headings + structured content) | Use `batch-update`: `insertText` for content + `updateParagraphStyle` for headings | `find-replace` inserts raw text into the existing paragraph — no heading, no list formatting. The new content looks like nothing changed because it's invisible plain text in a paragraph. Only use `find-replace` for text-within-text changes, never for structural additions. |
| Replying to a doc comment with "will do next session/cycle" instead of doing the work | Do the work immediately, then reply with what was done | Deferring to "next session" or "next cycle" is L8 (autonomy deficit). Default is act NOW — only defer if genuinely heavy (multi-hour research, cross-doc restructuring) or blocked (API down, missing info from user). Replying "acknowledged" without acting is worse than not replying — it creates a false sense of progress. |
| Trusting prior `[Claude]` replies as proof that work was done | Before replying "already addressed," verify the CURRENT doc state with `get-structure` or `gdocs get`. Check that the change is actually reflected. | Prior sessions may have replied "[Claude] Done" but the change could have: (1) failed silently, (2) been undone by a later edit, (3) never taken effect due to wrong find-replace match. A `[Claude] Done` reply is a CLAIM, not proof. Verify doc content against the comment's ask before echoing "already addressed." (Learned 2026-03-24: Cogwheel section had "[Claude] Done - moved" reply but was still a standalone h2 — 3 sessions repeated the false claim without checking) |
| Silently substituting an inferior solution when hitting a technical limitation | Stop and tell the user: "I can't do X properly via the API. Here's what you need to do manually: [specific steps]." | When an API operation is too hard (moving tables, complex cell fills), the temptation is to substitute something "close enough" (e.g., replace a table with a text paragraph). This destroys data and delivers something the user didn't ask for. The appearance of progress is worse than honest communication about limitations. Always flag the gap immediately — never silently downgrade. (Learned 2026-03-24: deleted a 6-row comparison table instead of admitting the move couldn't be done via API) |
| `insertText` at indices near the end of a table (within 2 of table endIndex) | Insert a new row first (`insertTableRow`), re-fetch structure, then fill cells using fresh indices | Content inserted at table boundary indices leaks OUT of the table as standalone paragraphs/headings. Rows can shift between adjacent tables. The table shrinks and surrounding content grows. Use find-replace to clean up leaked content. (Learned 2026-03-24: research overview doc table went from 20 to 16 rows, leaked content appeared as HEADING_4 outside table) |
| Inserting diff/task/URL references as plain text via `find-replace` | After `find-replace`, ALWAYS run `batch-update updateTextStyle` with `link` to make references clickable | `find-replace` inserts raw text — D-numbers, T-numbers, Conveyor IDs, and URLs appear as dead text that can't be clicked. Every reference inserted into a Google Doc must be a clickable hyperlink. Use `find-replace` for the text, then immediately follow with `updateTextStyle` to add `link.url`. This is a two-step operation, never one. "Reply done but didn't do the job" = inserting text without links. (Learned 2026-03-24: added Conveyor IDs and diff numbers as plain text, user had to call it out) |
| `echo "$json" \| python3 - <<'EOF' ... EOF` on multi-MB `gdocs get --raw-json` output | Write JSON to a temp file, then `python3 - <<'EOF'` with the temp path as `sys.argv[2]`: `with open(sys.argv[2]) as f: doc = json.load(f)` | The heredoc AND the pipe both try to become python3's stdin. The heredoc wins (script content), and the echoed JSON gets dropped — then echo gets SIGPIPE (exit 141) when its output buffer fills with no reader. On small inputs this is silent; on 8MB+ gdoc JSON the whole shell pipeline aborts mid-run, killing any post-push steps (widths, font, lint) that were supposed to follow. (Learned 2026-04-17: `lint_font_style` in cron-area-monitor.sh crashed with exit 141 at 03:06, leaving the AI Skill Monitor tab unformatted at 20pt all day) |
| `gdocs batch-update <DOC> --data @file.json` on large payloads | `cat file.json \| gdocs batch-update <DOC> --data -` (pipe via stdin) | `--data @file` hangs (exit 143 / SIGTERM) on sizable JSON payloads — gdocs CLI can't stream the file properly. Pipe via stdin with `--data -` fires reliably. Same pattern applies to `google-mux api call POST --data -`. (Learned 2026-04-18: area-monitor heading-size fix; batch-update hung twice in background, foreground with `timeout 45` + stdin worked) |

---

## Concurrency (multiple sessions editing docs)

Multiple Claude sessions may edit the same doc simultaneously. Follow these rules to avoid clobbering:

- **Temp files must include session ID**: Use `/tmp/gmux-<DOC_ID>-${CLAUDE_SESSION_ID}.html`, never bare `/tmp/gmux-<DOC_ID>.html`. This prevents two sessions from overwriting each other's working copies.
- **Prefer `batch-update` over round-trip for shared docs**: Round-trip (`edit`/`apply`) is a whole-doc replacement — if two sessions export, edit, and apply, the second apply silently overwrites the first. `batch-update` targets specific indices and is safer for concurrent use.
- **Re-fetch indices immediately before use**: Never cache `get-structure` output across multiple operations when other sessions may be writing. Always re-fetch right before each `batch-update` call.
- **Prefer position-relative inserts**: `insert-text --after-heading "Section"` or `--after-text "marker"` survive concurrent edits better than absolute index values.
- **One round-trip writer per doc at a time**: If you must use `edit`/`apply`, ensure no other session is doing the same. There is no locking mechanism — this is a discipline rule.

---

## batch-update Rules

All `batch-update` recipes share these rules:

- **Highest index first**: Order operations from highest to lowest index. Earlier operations shift all subsequent indices.
- **Structural changes in separate calls**: `insertTableRow`/`deleteTableRow` must be in a **separate** batch call from `insertText`/`updateTextStyle` — structural changes invalidate all indices.
- **Re-fetch between structural and content changes**: Always run `gdocs content get-structure` again after adding/removing rows before filling cells or applying styles.

---

## batch-update Recipes

### Adding Table Rows

**Step 1**: Find table start index using `gdocs content get-structure` (see Core Operations below).

**Step 2**: Insert empty row (separate batch call)
```bash
echo '[{"insertTableRow":{"tableCellLocation":{"tableStartLocation":{"index":TABLE_START},"rowIndex":LAST_ROW_IDX,"columnIndex":0},"insertBelow":true}}]' \
  | gdocs batch-update <DOC_ID> --data -
```

**Step 3**: Re-fetch structure to get new cell indices, then fill cells (separate batch call, reverse column order)
```bash
echo '[
  {"insertText":{"location":{"index":CELL3_START},"text":"cell 3 content"}},
  {"insertText":{"location":{"index":CELL2_START},"text":"cell 2 content"}},
  {"insertText":{"location":{"index":CELL1_START},"text":"cell 1 content"}},
  {"insertText":{"location":{"index":CELL0_START},"text":"cell 0 content"}}
]' | gdocs batch-update <DOC_ID> --data -
```

**Step 4** (optional): Add formatting — bold, links, colors
```bash
# Link only:
echo '[{"updateTextStyle":{"range":{"startIndex":START,"endIndex":END},"textStyle":{"link":{"url":"https://example.com"},"foregroundColor":{"color":{"rgbColor":{"red":0.067,"green":0.333,"blue":0.8}}}},"fields":"link,foregroundColor"}}]' \
  | gdocs batch-update <DOC_ID> --data -

# Bold + link:
echo '[{"updateTextStyle":{"range":{"startIndex":START,"endIndex":END},"textStyle":{"bold":true,"link":{"url":"URL"},"foregroundColor":{"color":{"rgbColor":{"red":0.067,"green":0.333,"blue":0.8}}}},"fields":"bold,link,foregroundColor"}}]' \
  | gdocs batch-update <DOC_ID> --data -
```

### Surgical Deletion

When `gdocs apply` fails with "Invalid deletion range" (common near table boundaries):

**Step 1**: Get character indices with `gdocs content get-structure <DOC_ID>`

**Step 2**: Delete content ranges (highest index first)
```bash
echo '[
  {"deleteContentRange":{"range":{"startIndex":150,"endIndex":200}}},
  {"deleteContentRange":{"range":{"startIndex":50,"endIndex":100}}}
]' | gdocs batch-update <DOC_ID> --data -
```

### Setting Proportional Column Widths

After inserting any table, set column widths proportional to content length to avoid empty space:
```bash
# Example: 4-column table. Short columns get ~54-72pt, long columns get ~200-234pt.
# Total should roughly equal page width minus margins (~468pt for letter).
echo '[
  {"updateTableColumnProperties":{"tableStartLocation":{"index":TABLE_START},"columnIndices":[0],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":72,"unit":"PT"}},"fields":"widthType,width"}},
  {"updateTableColumnProperties":{"tableStartLocation":{"index":TABLE_START},"columnIndices":[1],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":108,"unit":"PT"}},"fields":"widthType,width"}},
  {"updateTableColumnProperties":{"tableStartLocation":{"index":TABLE_START},"columnIndices":[2],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":234,"unit":"PT"}},"fields":"widthType,width"}},
  {"updateTableColumnProperties":{"tableStartLocation":{"index":TABLE_START},"columnIndices":[3],"tableColumnProperties":{"widthType":"FIXED_WIDTH","width":{"magnitude":54,"unit":"PT"}},"fields":"widthType,width"}}
]' | gdocs batch-update <DOC_ID> --data -
```

### Clearing Leaked Styles

```bash
echo '[{"updateTextStyle":{"range":{"startIndex":START,"endIndex":END},"textStyle":{},"fields":"backgroundColor"}}]' \
  | gdocs batch-update <DOC_ID> --data -
```

### Tab Sync (cron pattern — replace, not append)

For automated sync scripts that push content to individual tabs on a schedule:

```bash
# 1. Generate HTML content for the tab
python3 generate_tab_content.py > /tmp/gmux-tab-content.html

# 2. Replace tab content (clear + insert in one step)
gdocs replace "$DOC_ID" --from /tmp/gmux-tab-content.html \
    --tab-id "$TAB_ID" --untrusted-authors-mode --full-replace-removes-comments

# Key rules:
# - NEVER use insert-text for recurring sync — it appends (duplicates)
# - File must contain ONLY the target tab's content (<body>...</body>)
# - Store doc ID + tab mappings in config/ (survives devserver reinstall)
# - Use fd3 for while-read loops with heredocs: while read -r ... <&3; do ... done 3< file
```

---

## Style Verification After `gdocs apply`

Every `apply` can bleed adjacent inline styles. Verify immediately:

```bash
gdocs get <DOC_ID> --ghtml > /tmp/gmux-verify.html
grep -c 'background-color' /tmp/gmux-verify.html    # Should be minimal/expected
grep -c '<b>' /tmp/gmux-verify.html                  # Check for unexpected bold
grep -c 'font-family' /tmp/gmux-verify.html          # Check for font contamination
```

If leaks found, use the "Clearing Leaked Styles" recipe above — do NOT re-apply (causes more leaks).

---

## Visual-State Verification (Quality-Assurance gate — MANDATORY before claiming DONE)

**Rule:** A gdoc write is not DONE until the **visible browser state** is verified. Export-text dumps lie about hyperlink state in both directions; only the structure API tells the truth.

### What you CANNOT use to verify hyperlink correctness

- `meta google.docs get --output=text` — native gdoc hyperlinks render as **bare label text** here (no `<a href>` in export). Grepping `<a href` on this output is **inverted**: 0 matches = links work, N matches = N broken inline-HTML strings.
- `meta google.docs.append markdown` produces raw `<a href>` literal text outside table cells.
- Visual-inspecting your own input markdown.

### What you MUST use

```bash
# (A) Hyperlink presence check — every label that SHOULD be a link appears in this list:
meta google.docs structure --id=<doc> --tab-id=<tab> --output=json \
  | jq -r '.. | objects | select(.textRun? != null) | select(.textRun.textStyle?.link?.url != null) | "\(.textRun.content) -> \(.textRun.textStyle.link.url)"'

# (B) Raw-HTML-soup detection — ANY match here is a render failure (literal HTML in browser):
meta google.docs get --id=<doc> --output=text | grep -E '<a href="[^"]+">[^<]+</a>'
# Target: 0 matches. If >0, those `<a>` tags didn't get converted to native hyperlinks.
```

### Render-path → conversion coverage matrix

| Render path | `<a>` in table cell | `<a>` in bullet | `<a>` in paragraph | `<a>` in heading |
|---|---|---|---|---|
| `meta google.docs replace --markdown` | ✅ converts to native link | ❌ passes through as literal text | ❌ passes through as literal text | ❌ passes through as literal text |
| `meta google.docs replace` (ghtml, no `--markdown`) | ✅ | ✅ | ✅ | ✅ |
| `meta google.docs batch-update insertText` + post-pass `updateTextStyle.link.url` | ✅ | ✅ | ✅ | ✅ |
| `meta google.docs.append markdown` | ⚠️ cell links work, but no font/width/header-bg styling | ❌ | ❌ | ❌ |

**Picking the right path:**
- Tab needs links in tables only → `replace --markdown` is fine.
- Tab needs links in bullets/paragraphs/headers too → use **`replace` without `--markdown`** (ghtml input), OR `batch-update insertText` + per-occurrence `updateTextStyle.link.url`.
- Existing tab + comments → NEVER `replace` (destroys comments); use `batch-update` only.

### Failure mode this rule prevents (learned 2026-05-18)

Claimed ot-shift-summary 5/18 tab was done with "87 SEV anchors" — metric was `grep <a href` on `--output=text` dump. Reality: those 87 matches were 87 BROKEN inline-HTML strings sitting outside table cells, rendering as raw `<a href="https://...">S659917</a>` literal text in the browser. The operator opened the tab and saw HTML soup; I claimed DONE because export-grep gave a big number. Inverted metric.

**DONE criteria for any gdoc write (in order):**
1. **Visual-state verification** — hyperlink-presence check (A) returns the full expected set; raw-HTML-soup check (B) returns 0.
2. **Data depth** — no placeholder cells where data is derivable.
3. **Schema parity** — same H-level structure as the reference tab.
4. **Live freshness** — source data re-fetched at render time.
5. **No comments destroyed** — `meta google.docs comments list` count before == after for any non-`replace`-path edit.

A write that passes 2-5 but fails 1 is NOT done. Visual-state is the highest-priority gate.

---

## Installation

```bash
devfeature install google_mux --persist
```

## Core Operations

### Create

```bash
gdocs create "Title"                          # Empty doc
gdocs create "Title" --from notes.md          # From markdown
gdocs create --from report.html               # From ghtml (title from <title>)
gdocs create "Title" --folder <FOLDER_ID>     # In specific folder
```

### Read

```bash
gdocs get <DOC>                               # ghtml to stdout (always use this)
gdocs get <DOC> > /tmp/gmux-DOC_ID.html       # Save to file
gdocs get <DOC> --tab-id <ID>                 # Specific tab
gdocs get <DOC> --describe-images             # AI image descriptions
```

### Round-Trip Edit (the safe way to update)

```bash
gdocs edit <DOC> --output /tmp/gmux-DOC_ID.html   # Export
# ... edit the file ...
gdocs diff <DOC> /tmp/gmux-DOC_ID.html            # Preview changes
gdocs apply <DOC> /tmp/gmux-DOC_ID.html            # Apply changes
```

### Insert Content

All support `--tab-id`, `--index`, `--after-text`, `--after-heading`. Use `@file` for file input.

```bash
gdocs content insert-text <DOC> "text"                    # Plain text
gdocs content insert-text <DOC> @file.html --as-html      # HTML from file
gdocs content insert-markdown <DOC> "# Title\n**bold**"   # Markdown
gdocs content insert-image <DOC> <URI> --index 1          # Image
```

### Structure / Indices

```bash
gdocs content get-structure <DOC>              # Element types with start/end indices (preferred)
```

For detailed debugging (table cell indices, exact paragraph boundaries), use the raw API:
```bash
python3 -c "
import json, subprocess
result = subprocess.run(['google-mux', 'api', 'call', 'GET',
    'https://docs.googleapis.com/v1/documents/<DOC_ID>?includeTabsContent=true'],
    capture_output=True, text=True)
doc = json.loads(result.stdout)
body = doc['tabs'][0]['documentTab']['body']['content']
for elem in body:
    kind = 'table' if 'table' in elem else 'paragraph' if 'paragraph' in elem else 'other'
    print(f'{elem.get(\"startIndex\", \"?\"):>6} - {elem.get(\"endIndex\", \"?\"):>6}  {kind}')
    if 'table' in elem:
        print(f'         rows: {elem[\"table\"][\"rows\"]}')
"
```

### Find and Replace

```bash
gdocs content find-replace <DOC> "old" "new"                        # Case-insensitive
gdocs content find-replace <DOC> "old" "new" --match-case           # Case-sensitive
gdocs content find-replace <DOC> "{{X}}" @content.html --as-html    # Rich replacement
```

### Comments

Read comments via `gdocs get` (ghtml) — they're inline.

```bash
gdocs comments list <DOC>                              # List all comments (ID, author, content, resolved)
gdocs comments reply <DOC> <COMMENT_ID> "reply text"
gdocs comments delete <DOC> <COMMENT_ID>
```

| Wrong | Right | Why |
|-------|-------|-----|
| `gdocs comments <DOC>` | `gdocs comments list <DOC>` | `comments` is a subcommand group, not a command — requires `list`, `reply`, or `delete` |

### Permissions

```bash
gdocs permissions list <DOC>
gdocs permissions share <DOC> user@meta.com --role writer
gdocs permissions share <DOC> --type domain --domain fb.com   # All of Meta
gdocs permissions unshare <DOC> <PERMISSION_ID>
```

### Tabs

**Key insight**: `knowledge_load` (MCP tool) only returns the **first tab** of a Google Doc. To read other tabs, use the `gdocs` CLI with `--tab-id`.

**Workflow for accessing a specific tab:**
```bash
# 1. List all tabs to discover tab IDs
gdocs tabs list <DOC>
#  TAB ID           TITLE           INDEX
#  t.0              Daily Journal   0
#  t.d9parihvoj45   Eval Function   1

# 2. Read a specific tab's content
gdocs get <DOC> --tab-id t.d9parihvoj45

# 3. Get structure of a specific tab
gdocs content get-structure <DOC> --tab-id t.d9parihvoj45

# 4. Other tab management
gdocs tabs create <DOC> --title "Notes"
gdocs tabs rename <DOC> <TAB_ID> "New Name"
gdocs tabs delete <DOC> <TAB_ID>
```

Most `gdocs` subcommands that accept `--tab-id` work with any tab (read, get-structure, insert-text, find-replace, etc.).

### Export

```bash
gdocs export <DOC> --format pdf --output report.pdf
gdocs export <DOC> --format docx --output report.docx
```

## Temp Files

Always use `/tmp/gmux*` for temp files (e.g., `/tmp/gmux-DOC_ID.html`).

## ghtml Format

ghtml is a simplified HTML subset that round-trips losslessly through Google Docs. Preferred over markdown for editing — markdown is lossy (no colors, highlights, font changes, table formatting).

```html
<html>
<head><title>Doc Title</title></head>
<body>
<h1>Heading</h1>
<p>Text with <b>bold</b> and <a href="https://example.com">links</a></p>
<table>
  <tr><td style="background-color: #f0f0f0"><b>Header</b></td></tr>
  <tr><td>Value</td></tr>
</table>
</body>
</html>
```

Run `gdocs ghtml` for the full tag reference.

## Searching for Docs

Use `knowledge_filtered_search` with `doc_types: ["GOOGLE_DOCUMENT"]` and keywords. Load full content with `knowledge_load(url)`.

## See Also

- Full skill reference: `/usr/local/claude-templates-cli/components/skills/google-docs/SKILL.md`
- `career/project-doc.md` — for writing project proposals and specs
