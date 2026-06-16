# Proposal — autonomous early-warning loop (Problem #3) — NOT ENABLED

**Status: PROPOSED, build+propose boundary. Turning this on is the operator's switch.**
This document is the written design for closing Problem #3 ("Make urgent less urgent —
emit early signals before they page"). It does NOT enable any paging. Today the substrate
(`tools/trend-novelty.sh`, Problem #4) is OPERATIONAL: it refreshes daily inside
`ot-metrics-rollup` and writes the NOVEL + NOISE candidate lists to
`eval/reports/trend-novelty.{md,json}` — report-only, no chat, no escalation, no suppression.
This proposal describes what would have to be wired, and how it would be gated, to let a
NOVEL signature that crosses threshold *page the team*.

---

## 1. What exists today (the substrate, #4 — DONE)

- `tools/trend-novelty.sh` reads `triage_events` and groups every triaged item into a stable
  signature (`signal_class | failure-type | model`). Over a 28d window it emits:
  - **NOVEL / emerging** — NEW-class (unseen before window, ≥2 in-window), or RISING
    (this-wk ≥3 and ≥2× last-wk), or human-escalated. Candidates to flag for a human.
  - **NOISE** — high-volume (≥4) + ≥75% auto-handled + never human-escalated. Candidates to
    suppress with a known-issue TTL.
- It is **read-only on action**: writes the report files only; never pages, escalates, or
  suppresses. Thresholds are deliberately conservative because, per the eval README, the
  agent owns the precision of its own signals — a dud counts against it.
- Refresh is now daily via `ot-metrics-rollup` step 4 (folded, not a new cron).

The remaining gap (#3) is turning a NOVEL row that crosses a *paging* threshold into a single,
gated, one-message-per-event page to the team — and owning its precision.

---

## 2. Proposed loop (when the operator flips it on)

### 2.1 Trigger
A NEW reader cron step (or a new `ot-early-warning` cron — see §5 for fold-vs-new) reads the
fresh `eval/reports/trend-novelty.json` (NOT re-deriving — single source of truth is the
refreshed report) and selects NOVEL rows that cross a **paging threshold** STRICTER than the
report's flag threshold. Proposed paging gate (all must hold):

- `reasons` includes `RISING` with `this_wk >= PAGE_RISE_MIN` (proposed 4) AND
  `this_wk >= PAGE_RISE_FACTOR × last_wk` (proposed 3.0), OR `new_class` with
  `total >= PAGE_NEW_MIN` (proposed 3); AND
- the signature is NOT already covered by a live known-issue TTL (consult the known-issues
  registry — a suppressed/owned class must not page); AND
- the signature has NOT already paged within a **cooldown** (proposed 72h, keyed by signature)
  — prevents the same emerging class re-paging every day while a human works it.

Rationale for stricter-than-report: the report flags liberally for a human to *read*; a *page*
interrupts, so it needs a higher bar. The two thresholds are intentionally decoupled.

### 2.2 Output discipline (cron delivery discipline — HARD)
- **No-change run → `HEARTBEAT_OK` and nothing else.** If no NOVEL row crosses the paging
  gate, the cron emits exactly `HEARTBEAT_OK`. No "0 new" block, no status ping.
- **A page is ONE message**, one event → one message, fully formatted, BLUF first. Proposed
  shape (crisp, every line action-or-investigate):
  ```
  ⚠️ [OT early-warning] emerging signature crossing threshold
  <signal_class | failure-type | model> — last→this wk N→M (+Δ WoW), <NEW-class|RISING>
  Evidence: <2 example signals from the report>
  Not yet a SEV. Suggested owner: @<unixname>. Report: eval/reports/trend-novelty.md
  ```
- Posted to the team space `spaces/AAQA2bZMw24` ONLY when it is genuinely team-wide emerging
  signal (passes the team-chat 2-question gate: AUDIENCE team-wide? DENSITY every line earns
  its place). A borderline/ambiguous signature routes to the operator 1:1
  (`spaces/AAQAVOjYc80`) instead, never both.
- Threaded per the GChat reply discipline (new-topic only for a genuinely new emerging class).

### 2.3 /mute kill-switch (HARD)
The page path is gated by the existing `/mute` kill-switch (`kill_switch.duration_minutes`,
default 60, any space member can invoke). If muted, the cron does NOT page — it still refreshes
the report (that path is already in metrics-rollup and is unaffected) and responds
`HEARTBEAT_OK`. Mute is checked immediately before any send, same mechanism the daemon uses.

### 2.4 Precision accountability (the contract)
Per the eval README, the agent **owns the precision of its early signals — a dud page counts
against it, else it degrades into Problem #4's noise.** So every page is logged to a
ledger (proposed `eval/reports/early-warning-ledger.jsonl`: signature, date, evidence,
disposition) and scored:
- **Disposition** is harvested later (by an existing daily-learning cron or a small reader):
  did this emerging class become a real SEV/alert within N days (TRUE early signal), get
  human-confirmed worth-watching (HELPFUL), or fizzle with no action (DUD)?
- A rolling **page precision** (TRUE+HELPFUL / total pages) is computed and surfaced in the
  eval scoreboard. If precision falls below a floor (proposed 0.6 over the last 10 pages), the
  loop auto-quiesces (stops paging, keeps reporting) and flags the operator to re-tune
  thresholds — the same "a dud costs precision" guardrail the substrate already encodes.

---

## 3. Why this respects every standing rule

- **Build+propose boundary:** nothing here is enabled. The refresh (already live) is
  report-file-only. The paging step ships disabled.
- **External-surface read-only:** the loop's only write is a GChat message (the sole surface
  the bot may write to). No SEV/alert/Workplace/Phabricator mutation; no auto-suppress (the
  NOISE→known-issue-TTL action stays human-approved, unchanged).
- **Cron delivery discipline:** `HEARTBEAT_OK` on no-change; one message per event; crisp.
- **Anti-cron-proliferation:** prefer folding the reader into an existing daily cron over a
  new one (§5).
- **Org boundary / no individual-scoped data:** the substrate already inherits the org filter
  (only in-scope MRS triage_events feed it); a page carries only team-visible OT signal.

---

## 4. Exactly what remains to make #3 go live (operator's switch)

All gated on operator approval. None is done in this build:

1. **Operator approval of the paging thresholds** (§2.1): `PAGE_RISE_MIN`, `PAGE_RISE_FACTOR`,
   `PAGE_NEW_MIN`, cooldown, precision floor. These are proposed numbers, not validated against
   a corpus of would-be pages — the operator (or a dry-run, §4.5) should confirm them.
2. **The reader/pager step** — a small script (proposed `tools/early-warning-page.sh`) that
   reads `trend-novelty.json`, applies the paging gate + known-issue + cooldown checks, and
   either composes ONE page or exits clean. Ships report-only first (logs would-be pages to the
   ledger, sends nothing) so its precision can be measured BEFORE it ever interrupts anyone.
3. **Wiring the send** — only after the dry-run shows acceptable precision: enable the actual
   `meta google.chat.message send` (team-or-1:1 routing per §2.2), gated on `/mute`.
4. **The disposition harvester** — wire ledger scoring into an existing daily-learning cron so
   page precision is computed and surfaced on the scoreboard; wire the auto-quiesce floor.
5. **The switch itself** — a single config flag (proposed `early_warning.paging_enabled: false`
   in `team_bot_config.yaml`, default false). Flipping it true is the operator's call and the
   only thing that turns paging on; everything upstream can run (and be measured) with it false.

Recommended rollout: land steps 2+4 in **dry-run** (ledger only, `paging_enabled: false`),
let it accumulate a week of would-be pages, review precision with the operator, then flip the
switch. This makes the precision contract (§2.4) real before the first interrupt.

---

## 5. Fold-vs-new for the paging reader (deferred to enablement)

The daily *refresh* is already folded into `ot-metrics-rollup` (done). For the *paging reader*,
the same anti-proliferation rule applies. Options at enablement time:
- **Fold into `ot-metrics-rollup`** (reads the report it just refreshed in the same run) —
  cleanest, zero new cron, but couples paging cadence to 09:00 PT daily.
- **Fold into the monitors** (`ot-sev-monitor` runs every 15 min) for faster lead time — but
  those are team-facing already and adding a second message type risks noise.
- **New `ot-early-warning` cron** — only if a distinct cadence (e.g. hourly) is wanted and the
  operator accepts a new cron for it.

Recommendation: fold into `ot-metrics-rollup` for the dry-run (it already reads the report),
revisit cadence only if lead time proves too slow.

---

_Source: eval README Problems #3/#4; built alongside the #4 substrate refresh fold,
2026-06-12. Refresh is live; paging is proposed-not-enabled._

---

## 6. Second substrate (2026-06-13) — METRIC-trend early warning (`early-warning-detect.sh`)

§1–§5 above build #3 on the **signal-class** substrate (`trend-novelty.sh`): an emerging
*category* of triaged item. That is the "have we started seeing a new KIND of failure" axis.

There is a second, complementary axis the operator named as the PRIMARY metric for #3:
**a single model's training example age trending toward the unhealthy line BEFORE it breaches.**
This is "is THIS model about to go stale" — caught from the live metric, not from triage
history. `tools/early-warning-detect.sh` is that substrate, also REPORT-ONLY, also folded into
`ot-metrics-rollup` (step 7).

### 6.1 What it does (mechanics)
- Metric: `dpp_worker.scribe_example_age_ms.avg.60` (KM-T1), model-level rollup entity — the
  EXACT source+query as `scan-scribe-age.sh` / `eval-online-correlate.sh` (single source of
  truth), but it keeps the full 4h @ 5m **series** to fit a trend instead of taking the MAX.
- Bands (KM-T1): healthy <5min · elevated 5–30min · unhealthy/SEV >30min.
- Flags **APPROACHING** when a model is in the *elevated* band AND *rising* toward 30min
  (OLS slope ≥ `--min-slope`, default 1.0 min-age/hr), with an estimated
  lead-time-to-breach = (30 − current)/slope.
- Records events to `eval/reports/early-warning-history.jsonl` (idempotent per model+day) and
  every scanned model's age to `eval/reports/early-warning-observations.jsonl` (the per-model
  ground-truth trace reconciliation reads).
- **Reconciles** past approaching-events against outcomes: later breached >30min →
  TRUE_POSITIVE; recovered → RECOVERED (candidate false-alarm). Computes running **precision**
  + **median lead-time**, honestly printing `ACCRUING — N settled, need ~M` until ≥20 settle.
- Writes `eval/reports/early-warning.md`. NEVER pages/escalates/mutates; read-only on action.

### 6.2 What it accrues + when the gate can be calibrated
The calibration input is **settled events** (not runs). Each approaching event settles only
after its lead window elapses and a post-event observation is seen. Precision is reported as a
number only at ≥20 settled events (`--need-events`); below that the gate stays OFF and the
report self-reports the count toward 20. On a healthy fleet only a few models approach on any
day, so ~20 settled events is on the order of **2–4 weeks** of daily accrual (faster on noisy
weeks). The substrate makes "are we ready yet?" a number the operator can read, not a guess.

### 6.3 The switch (same shape as §4–§5, operator's)
Once precision + median-lead are trustworthy: the operator picks a precision floor (bounded
false-alarm rate), then flips the gate ON — only then may an approaching-event whose confidence
clears the floor page (team-or-1:1 routed per §2.2, gated on `/mute`, one-message-per-event).
The same `early_warning.paging_enabled: false` flag (§4.5) governs both substrates. Until then,
this is a measurement, not an actuator — the page remains a deliberate boundary expansion that
is the operator's explicit decision.

_Built 2026-06-13. Detector + reconciliation live (report-only) inside `ot-metrics-rollup`;
paging proposed-not-enabled._
