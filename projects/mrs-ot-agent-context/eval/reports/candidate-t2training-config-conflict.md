# Candidate — T2-training lift: model-side config-conflict failure class (P62 / R23)

**Status:** PROPOSAL — NOT landed. Awaiting an eval A/B that clears the ±0.03 noise band.
**Target component:** T2-training (~0.63 in Scoreboard; iter9 isolated the drag to ~0.56 on this class).
**Author:** build+propose pass, 2026-06-12. Single candidate, falsifiable, A/B-able.

---

## 1. Diagnosed failure mode (grounded in case ids)

The T2-training component is **not** dragged down by the P-row-backed training cases —
iter9 baseline replays confirmed the agent gets those right:

- `ALERT-1533487445064477` (P44 GIL hang) — baseline rc=1, p_row=1, verdict=1. NOT a gap.
- `W1347152497379493` / `W1342215704539839` (P61 zombie trainer) — baseline rc=1, p_row=1. NOT a gap.
- `A1703030847735006` / `A25209897055308328` (P56 Shampoo NaN), `S665454` (CUDACachingAllocator),
  `S667567`/`POST-1332867342141342` (rank-7 SIGSEGV) — all carry P-rows; baseline applies them.

Of the ~17 T2-stage cases in `gold-set.json` (v2026-06-12-iter10), **exactly one** has
`ground_truth.p_row == "none"`:

- **`W1342971631130913`** (post, `mrs_online_training`, model 2121486280 `ig_textpost_feed_esr`).
  - **Input symptom (what the agent sees):** "Online train kept failing and delta track config
    not being populated. Three embedding tables (`media_embedding_cache`, `always_on_media_id`,
    `always_on_author_id`) missing from `skip_embedding_table_names` in the mvai train config.
    Job fails with `torch.cat(): expected a non-empty list of Tensors` on restart."
  - **Confirmed RCA (ground truth):** "**Duplicate sparse streaming config specified in BOTH
    `trainer_config` AND `delta_publish_config`** — a long-standing tech-debt in the *model*
    config (model-side, not OT infra). Fix: D107578770." Owner `xiaozang / ig_textpost_feed_esr`,
    verdict `REAL_OT_FAILURE`, confidence 0.75.
  - Source archive: `incidents/resolved-posts/2026-06/2026-06-08-W1342971631130913.md` (author
    Xiao Zang's `#resolved` comment states the RCA verbatim).

**Why the agent diverges (the recurring failure mode):**
1. **Wrong root-cause class.** With no P-row to anchor on, the agent reasons from first principles
   off the *symptom* text. The body foregrounds two **downstream manifestations** —
   `torch.cat()` on empty tensors, and the three missing `skip_embedding_table_names` entries —
   so the agent stops at "delta-tracker / publish-path misconfig" (a T3 publish-infra framing)
   instead of the **upstream model-side config conflict** that produced both symptoms. The
   archive's own validator note flags this exact trap: "the 3 missing tables are a *downstream*
   manifestation of the dup config, not separately stated as root cause."
2. **Wrong owner / scope.** Symptom-anchored reasoning routes this to OT-infra/MVAI-publish.
   The confirmed answer is **model-side** (the model owner's config tech-debt), so `owner_match`
   misses and the verdict, while `REAL_OT_FAILURE`, is mis-scoped to infra.
3. **Calibration cost.** A confident-but-wrong-class diagnosis is exactly what the
   calibration-weighted fitness (.35) punishes hardest.

This is a *class*, not a one-off: "model-side config conflict surfacing as an OT
runtime/publish symptom" is the missing knowledge cell — every existing R-rule covers infra
stages (R14 STUS, R15 disabled flow, R16 alert-applicability, R17 trainer-liveness, R18
diagnosed-stage scope, R19 retrieval SPARSE_DELTA) but **none covers a model-config conflict**.

---

## 2. The ONE candidate

A new R-rule (reasoning fix), framed generally so the win is **generalization, not memorization**
of S/W ids. It teaches the agent to recognize the *signature* of a model-side config conflict and
to treat `torch.cat()`-on-empty / "delta-tracker config not populated" as a **downstream symptom**,
walking back to the config layer before naming a publish-infra cause.

> **R23 — Empty-tensor / "config not populated" on an OT job = walk back to a MODEL-SIDE config
> conflict before blaming publish/delta infra.** When an OT training job fails with
> `torch.cat(): expected a non-empty list of Tensors` (or an analogous "empty list / not
> populated / missing tables" error in the delta-tracker / sparse-streaming path), and the symptom
> text names `skip_embedding_table_names`, `delta_publish_config`, `trainer_config`, or
> "delta tracker config not populated", treat the empty-tensor failure as a **downstream
> manifestation**, not the root. **Procedure:** check whether the *same* sparse-streaming /
> embedding-table config is declared in BOTH `trainer_config` and `delta_publish_config` — a
> duplicate/conflicting declaration makes one path see an empty table set, yielding the empty-tensor
> cat. **If a duplicate/conflicting config is the mechanism → root cause is a MODEL-SIDE config
> conflict (model owner's tech-debt), verdict REAL_OT_FAILURE, owner = the model owner (not
> OT-infra / MVAI-publish), fix is a model-config dedup (e.g. D107578770-class).**
> **Falsifier:** if the embedding/sparse-streaming config is declared in exactly one place and the
> empty-tensor error persists → NOT a config conflict; fall through to publish-path triage
> (P02/P23/P60). Source: W1342971631130913 (ig_textpost_feed_esr 2121486280, 2026-06-08,
> author-confirmed dup sparse-streaming config in trainer_config + delta_publish_config).

(If/when 2 more sources appear, promote the same content to **P62** in `known-patterns.md`
— symptom→cause→fix row — per the ≥3 distillation bar. Until then this is the R-rule form, which
needs only 1 confirmed source because it is a *reasoning* fix, not a pattern claim.)

---

## 3. Exact `inject_rule` string for the A/B

Run both arms on the SAME gold-set version (currently `2026-06-12-iter10`). Baseline = no
`inject_rule`; treatment = the string below.

```
inject_rule = "R23: If an OT training job fails with 'torch.cat(): expected a non-empty list of Tensors' (or an analogous empty-list / 'config not populated' / 'missing tables' error in the delta-tracker or sparse-streaming path) AND the symptom mentions skip_embedding_table_names, delta_publish_config, trainer_config, or 'delta tracker config not populated', treat the empty-tensor failure as a DOWNSTREAM symptom, not the root. Check whether the same sparse-streaming / embedding-table config is declared in BOTH trainer_config AND delta_publish_config: a duplicate/conflicting declaration makes one path see an empty table set, producing the empty-tensor cat. If so, the root cause is a MODEL-SIDE config conflict (the model owner's config tech-debt) — verdict REAL_OT_FAILURE, owner = the model owner (NOT OT-infra / MVAI-publish), fix = model-config dedup. Falsifier: config declared in exactly one place and error persists -> not a config conflict; fall through to publish-path triage (P02/P23/P60)."
```

How to run (interactive, daemon path stalls per iter12):

```
Workflow {scriptPath: "/home/dennyzhang/.myclaw-ot-bot/eval-flow.js",
          args: {ts: "<now ISO>", source: "interactive",
                 inject_rule: "<the R23 string above>"}}
```

then compare `fitness.by_component["T2-training"].root_cause_accuracy` and the headline
`fitness.composite` against a baseline run (no `inject_rule`) on the same gold version.

---

## 4. Cases it should fix + expected lift

**Should flip:** `W1342971631130913` — `root_cause_match` 0→1 (mechanism now named: dup config,
not publish infra), `owner_match` likely 0→1 (model owner vs infra), calibration improves
(right-class + confident). No other gold case has this signature, so **zero regression risk** on
the rest of the corpus is expected (the rule is gated by a very specific symptom signature).

**Expected lift (back-of-envelope, single-build, honest):**
- T2-training component `root_cause_accuracy`: with ~17 T2 cases, fixing the one structural miss
  moves the component by ~`1/17 ≈ +0.06` on rc — i.e. roughly the ~0.63 → ~0.69 the Scoreboard
  target implies, IF this case is the dominant drag (iter9 says it is).
- Headline `composite`: 1 of ~57 graded cases improving on rc+owner+calibration is a
  **small, likely sub-noise-band** move on the *global* composite (the ±0.03 band is on the
  60-case composite). So the decisive metric is the **per-component** number, not the headline —
  judge the candidate on `by_component["T2-training"].root_cause_accuracy`, and require the
  W1342971631130913 row to flip to rc=1 with no new misses elsewhere.

**Verification / acceptance test:**
1. Treatment run shows `W1342971631130913` rc_match = 1 (was <1) and owner_match improved.
2. No previously-passing case regresses to rc < 1 (diff the `failures[]` lists).
3. `by_component["T2-training"].root_cause_accuracy` rises by ≥ the single-case delta (~0.06)
   and `hallucination_rate` does not increase.
4. Only THEN land R23 into `human-input/triage-discipline.md` (and queue P62 for when 2 more
   sources arrive). If the global composite move is inside ±0.03 but the per-component +
   single-case flip are clean and regression-free, this is the intended "narrow, correct, low-blast"
   commit — the component target is the rationale, the global band is not the gate for a
   single-case structural fix.

---

## 5. Honest caveats

- **Sample size is 1** for this failure class in the gold set. The candidate is a *reasoning* rule
  (R-rule, 1-source bar) precisely because the pattern bar (≥3) is not met. A real P62 must wait
  for 2 more sources (currently 1/3 — the prior plan).
- **Leak check:** the rule names a symptom *signature* (empty-tensor cat + dup config in two config
  blocks) and a *general* routing conclusion (model-side, model owner), not the specific S/W id or
  the specific three table names — so a win is generalization, not coverage. The grader's
  `leak_suspect` flag should stay false; verify it does in the A/B.
- **A/B not run in this pass:** the full eval stalls in the daemon path (iter5/iter12) and a
  reliable interactive 60-case run is heavy; this proposal delivers the candidate + the exact
  inject_rule + the acceptance test rather than a fabricated delta. A cheap single-case interactive
  replay (triage W1342971631130913 with vs without the rule, then grade) is the minimum check
  before a full run.


---
## A/B RESULT (2026-06-13): R23 REJECTED — no flip
Single-case A/B on `W1342971631130913` (shard 73, shard_size 1), baseline vs R23 `inject_rule`:
- Baseline: rc 0.5 · hallucination 1 (gated) · composite 0.
- Treatment (R23): rc 0.5 · hallucination 1 (gated) · composite 0 — **NO CHANGE**. The agent tripped R23's own falsifier (judged the config single-location, not dual-declared) and kept its prior mechanism. R23's downstream-framing + owner-routing were already right at baseline. **Do NOT land R23.**

**The real bug the A/B exposed:** `triage-discipline.md` step 2-d's worked example for this incident asserted the bot's WRONG original hypothesis (`skip_embedding_table_names` missing 3 RES tables) as 'the real root cause'. The archive shows the owner corrected it to a duplicate trainer_config/delta_publish_config tech-debt (D107578770). The agent read the wrong example → hallucinated it (halluc=1). **Fix landed:** corrected 2-d to mark skip-tables as a hypothesis the owner overrode (leak-safe — does not name the gold answer). This should drop the hallucination on this case; re-A/B to confirm.
