# `mega/` — superseded alternative curation (W22–W24), MERGE PENDING

**Status: ORPHAN. No cron reads or writes this directory.** The canonical weekly
mega-learnings path is `auto-learnings/digests/<YYYY>-W<NN>.md` (written by
`ot-knowledge-curation`, read by `ot-human-attention-brief` + `ot-shift-summary`).

These three files (`2026-W22/W23/W24.md`) are a **second, more granular curation
pass** of the same weeks that briefly landed here before the path was
standardized to `digests/`. They are NOT duplicates of the `digests/` versions:

- The headers are mis-dated (e.g. W22 says "May 18–25"; the entries inside are
  actually May 25–31 = the canonical `digests/2026-W22` window).
- They overlap the `digests/` versions only partially. Many entries are the same
  learning **reworded**; several are **genuinely unique** learnings absent from
  canonical `digests/` (e.g. `BOOST_PP_LIMIT_SEQ=256` aarch64 conveyor block,
  DPP xregion/Zeus-TTL, S668542 scribe write-quota cascade, TMS auto-restart
  bootstrap gap).

**Why not auto-merged:** because reworded-duplicate vs genuinely-unique cannot be
told apart mechanically, an automated append into the canonical `digests/` files
would pollute them with near-duplicates. Merging requires per-entry semantic
judgment.

**TODO (focused follow-up):** human-reviewed semantic merge of the unique
`mega/` learnings into the matching `digests/<week>.md`, then delete this
directory. Until then, treat `digests/` as authoritative and this as a richer
historical reference. Do not wire any cron to read `mega/`.

_(Flagged during the 2026-06-10 context-folder deep-clean audit.)_
