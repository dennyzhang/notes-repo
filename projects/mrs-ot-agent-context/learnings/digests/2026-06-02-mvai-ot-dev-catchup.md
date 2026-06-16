# 2026-06-02 — MVAI OT Dev catch-up (gchat `spaces/AAQAXSNWvcM`)

_Auto-distilled by `context-ingestor-gchat` cron. Source: 8 new human messages spanning 2026-06-01T10:07 → 2026-06-01T23:12 PT in **MVAI OT Dev** (8 members; primary contributors: Denny Zhang × 4, Li Lu × 3, Paul Lu × 1)._

_Window: 7d default (delta since last_msg_create_time 2026-05-28T17:05 PT). Skip-until: not set (active polling)._

## P0 — bot-integration-blocking items

**Shift-left triage initiative — new early-warning alerts landing**

Denny described a "shift-left triage" initiative (UGqqQCiPZaE, 2026-06-01T10:10): "Currently oncall receives 5ish major alerts, which will phone call people off bed. I'm adding earlier alerts to make urgent issues less urgent." Multiple diffs in review:

- **D106832890** — raw event logging stack for delta publisher (7 diffs total, Denny stacked on Paul Lu's base). Li Lu reviewing, added comments (2026-06-01T23:12). Scuba table not yet confirmed — Li Lu asked, no answer captured.
- **D106903024** — "[Shift-left triage] Add WARNING tier to IFR Watchtower 'too few delta snapshots' alert." Li Lu accepted.

Bot implication: once these land, the `ot-alert-monitor` cron will start seeing new WARNING-tier alerts for IFR Watchtower "too few delta snapshots." These are intentionally early-warning, not page-level — the bot should triage them at lower urgency (Cat-1 not Cat-0) and not treat them as immediate failures. The existing page-level alert is the escalation path if the WARNING is ignored.

## P1 — significant nuance / sub-mechanisms

**Delta publisher raw event logging — scuba table TBD**

Li Lu asked (2026-06-01T11:35): "which scuba table do they log to?" No answer captured in the window. This is a gap — once the logging diffs land, the bot needs the scuba table name to query delta publisher event state during triage.

Action: follow up with Denny or Paul Lu to confirm scuba table name before this diff stack lands.

**D106566401 — max-retries OT behavioral change (prior run, confirm landed)**

From prior context (2026-05-28): Paul Lu's D106566401 "[mvai][fire] Simplify max_app_retries handling and remove prod OT reset logic" was accepted by Li Lu. If landed, OT jobs no longer support `-1` (infinite retries). Bot's triage context for "OT job appears stuck in retry loop" may need to be updated — infinite retries is no longer a valid failure mode.

**D106588525 — fire --dry-run bug fixed (prior run, confirm landed)**

D106588525 fixes fire ignoring `--dry-run` for TMS operations (S668272 context). Shengpei completed review. If landed, this closes a reliability hole where dry-run testing was silently operating on prod TMS state.

## P2 — references / good-to-know

- D106832890 — delta publisher raw event logging base diff. 7-diff stack. Paul Lu reviewing.
- D106903024 — IFR Watchtower WARNING tier for "too few delta snapshots." Already accepted.
- SLICK missing-item debugging still blocked — Anthony Foiani was blocked by feed ranking infra outages week of 2026-05-26. Denny wanted to close all SLICK gaps that week; deferred.

## Cross-references

None this week.

## Open coordination threads

- **Scuba table for delta publisher logging** — Li Lu asked, unanswered. Should resolve before diffs land.
- **SLICK gap closure** — Denny's goal was end-of-week 2026-05-30; deferred due to Anthony Foiani's bandwidth. No new timeline visible.

## Integration priority table

| Priority | Item | Cron prompt change | Time est |
|---|---|---|---|
| P0 | IFR Watchtower WARNING "too few delta snapshots" — treat as Cat-1 not Cat-0 | Add to `ot-alert-monitor` cron: IFR Watchtower WARNING tier is shift-left signal, not page-level | 15 min (after D106903024 lands) |
| P1 | Confirm scuba table for delta publisher event log | Add to canonical sources section once confirmed | 10 min |
| P1 | OT max-retries: confirm D106566401 landed; remove "infinite retry" from failure mode list | Update `known_patterns.md` failure class for "OT job stuck in retry loop" | 20 min |
