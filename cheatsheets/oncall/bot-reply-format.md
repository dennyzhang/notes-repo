# Bot Reply Format — Triage / Investigation Drafts

Template for triage/investigation replies pasted into GChat, Workplace, DM, Phabricator. Optimized for fast digestion.

**Two laws:**
1. **No prose walls.** Tables, bullets, verbatim logs. If a sentence is >2 lines, compress or split.
2. **Every claim has adjacent evidence** — log line, URL, paste ID, command output, or timestamp. No floating assertions.

**Load before drafting:** oncall triage reply, SEV summary, OT investigation, DM to owner, handoff message.
**Pairs with:** `feedback_verbatim_logs_in_drafts.md`, `feedback_draft_leads_with_component.md`, `oncall/mast-debugging.md`.

---

## Skeleton (copy, fill, trim)

```
Broken component: <subsystem> (<rank/location>, called from <call site>).
Suggested action: <concrete command | diff# to revert | oncall to page>.

<job/model> (<type>) <symptom> since <time> — <headline metric>.
  Evidence: <Bunny URL | attempts URL | dashboard URL>

Root cause (<deterministic | flaky>, <N> attempts):

  <verbatim log line — copy-paste, do not retype>

<Cascade — only if MAST outer ≠ true trigger>
MAST-reported outer (cascade):

  <verbatim outer log line>

Failure chain: <rank X crashes> → <downstream> → <killer>.

Attribution: <owner team + diff#>. NOT <wrong oncall> — <one-line reason>.

Evidence:
- <Bunny URL>
- <Job Inspector URL>
- <paste ID / fire cmd>
```

---

## Element Rules (every row has a claim + evidence example)

| Element | Rule | Evidence form |
|---|---|---|
| **Lead: component** | Name the subsystem where the exception TYPE originates. Caller ≠ culprit. | `IENException` → IEN · `GlooException` → Gloo · `OOMError` → trainer · `ScribeClientException` → Scribe |
| **Lead: action** | Concrete command, diff#, or oncall. Never "investigate further". | `revert P2286002932` · `mvai online-training-mgr -m X -s off` · `page DPP oncall` |
| **Context line** | Job/model + one-line symptom + time + headline metric + inline URL. | `job X crash-looping since 09:29 — 3 DEAD attempts (Bunny: fburl/...)` |
| **Log: verbatim** | Full line: `[trainer<N>]:E<date> PID file.py:line [Rank X] [tags] message`. Never retype. | Copy from `meta ai.mast-job error` or `fetch_mast_job_errors_tool` output |
| **Deterministic flag** | State "byte-identical across N attempts" or "intermittent, <freq>". | Back with attempt count + URL list or frequency metric |
| **Cascade** | Show outer MAST error only if it differs from true trigger. Lead with inner. | Both verbatim; one-line note explaining inner → outer |
| **Failure chain** | Arrow notation in one line. No multi-sentence explanation. | `rank 0 IEN dies → ranks 1-7 GLOO closed → rank 4 SJD killed` |
| **Attribution** | Name owner team + diff#. Name wrong-oncall to exclude. | `fire-app:754cc3f + P2286002932 (@sharondong). NOT minimal_viable_ai.` |
| **Evidence block** | Bunny + Job Inspector + paste URLs at bottom. Minimum 2 links. | Full URLs, not "see dashboard" |

**Tag→subsystem map:** `[GPU_OPTIMIZATION]` → IEN · `[MINIMAL_VIABLE_AI]` → MVAI platform · `[DPP]` → DPP · `[HEDWIG]` → Hedwig streaming · `[NCCL]` → NCCL/torch dist.

---

## Length Variants

| Venue | Lines | Keep | Drop |
|---|---|---|---|
| **Full DM to owner** | 25–35 | Lead + context + inner log + outer cascade + chain + attribution + 3+ links | nothing |
| **GChat thread / oncall space** | 12–18 | Lead + context + inner log + attribution + 1 Bunny link | outer cascade, chain (inline if critical) |
| **Workplace post** | 20–25 | Lead + context + inner log + chain + attribution + all links | full outer stack (one-line it) |
| **Phabricator draft reply** | 5–10 | Lead + the one verbatim log backing the comment | everything else — diff is the context |
| **Issue report (XFN escalation)** | 5–8 | 1-2 paragraphs: what broke + scope + question for XFN team + paste ID | Everything else goes in the paste. See `oncall/issue-report.md` |

---

## Claim → Evidence Pairs (required patterns)

| Claim made | Evidence that MUST appear adjacent |
|---|---|
| "Crash-looping" | Attempt count + duration table OR attempts URL |
| "Byte-identical error" | ≥2 verbatim log lines OR explicit "log at attempt 0, 1, 2 — same line:line and message" |
| "Deterministic, not flaky" | All-N-attempts citation, not "based on one log" |
| "Component X is broken" | Verbatim log with `[tag]` and exception class name |
| "Not a platform issue" | Exception class + tag that's NOT `[MINIMAL_VIABLE_AI]` OR platform repo path |
| "Regression surface is diff Y" | `fbpkg info` build timestamp + diff URL/paste ID |
| "Job keeps relaunching" | TMS state (`ONLINE_READY`) + attempt count + `tms_restarted` field |
| "Missing full snapshot" | `DeltaOnlyPublisher` retry log OR absent `ModelPublishSuccess` in Scuba |
| "Rank N is stuck" | SJD `StuckJobException` verbatim + lease metadata snapshot |

If you can't pair a claim with adjacent evidence, delete the claim.

---

## Anti-Patterns (caught in past drafts)

| Anti-pattern | Fails because | Fix |
|---|---|---|
| "Crash-looping since 09:29" as lead | Reader can't route | Lead with `Broken component: X. Suggested action: Y.` |
| "TGIF publisher is broken" | Caller ≠ culprit | Name exception-origin (`IENException` → IEN) |
| "IENException about index 39" | Can't grep / verify | Paste full `[trainer0]:E0423 ... file.py:line ...` |
| "Investigate further" / "TBD" | Not actionable | Name command, diff#, or oncall |
| "Not a platform issue" alone | Reader still routes to platform | Also name the wrong oncall by name + one-line reason |
| Only MAST outer error | SJD chases the red herring | Show both; inner first, outer as cascade |
| "See logs" / "see dashboard" | Re-query burden | Paste exact URL |
| Prose paragraph explaining cascade | Skim-hostile | One arrow-notation line: `A → B → C` |
| "Same issue as last time" | No verifiable anchor | Link to prior SEV / paste / Bunny URL |

---

## Tone

| Do | Don't |
|---|---|
| Flat, direct | "Hi team!", "Absolutely!", "Great catch!" |
| State broken thing + action | Editorialize ("you broke it") |
| Offer help in 1 line if useful | "Happy to assist with anything you need!" |
| Match recipient energy (peer DM = terse) | Verbose when recipient is terse |
| Name owner + diff # | Vague "owner team should look" |

---

## Worked Example (mvai-training-online-2126402930, 2026-04-23)

```
Broken component: IEN / GPU_OPTIMIZATION (rank 0, called from
tgif_async_publish). Suggested action: owner to revert local diff
P2286002932 + rebuild fire-app; pause TMS with
`mvai online-training-mgr -m 2126402930 -s off` to stop the
crash-loop from burning 8x H100.

mvai-training-online-2126402930 (ig_threads_replies_mtml) crash-looping
since 09:29 PDT — 3 DEAD attempts, full snapshot never generates.
  Attempts: https://fburl.com/mast/mvai-training-online-2126402930

Root cause (deterministic, byte-identical across all 3 attempts):

  [trainer0]:E0423 12:41:57.684 5809 tgif_publisher.py:432 [Rank 0]
  [TGIF publish] Publish failed on rank: [0], exception:
  [PLATFORM_ERROR][GPU_OPTIMIZATION] IENException: index 39 is out
  of bounds for dimension 0 with size 39
  (same line:line and message at 10:19:04, 11:30:26, 12:41:22)

MAST-reported outer (cascade, not the real trigger):

  [PLATFORM_ERROR][MINIMAL_VIABLE_AI] StuckJobException: stuck during
  lease(s): mvai_monitor... Rank: 4 (hard_timeout_secs=1200)

Failure chain: rank 0 IEN dies in tgif_async_publish → ranks 1-7 hit
GLOO "Connection closed by peer" → rank 4 stuck in broadcast → SJD kills.

Attribution: fire-app:754cc3f + P2286002932 (built 09:28 today by
@sharondong). NOT minimal_viable_ai oncall — exception class +
`[GPU_OPTIMIZATION]` tag = IEN layer, not platform.

Evidence:
- Bunny: https://www.internalfb.com/intern/bunny/job/mvai-training-online-2126402930/0/2
- Job Inspector: https://fburl.com/ai_infra/job_inspector/guided/stuck_job?jobName=mvai-training-online-2126402930&jobVersion=0&jobAttempt=2
- Fire cmd paste: P2286003058
```

Every claim in that draft has adjacent evidence: lead cites the exception type → log below; "crash-looping since X" → attempts URL; "byte-identical" → 3 timestamps; "regression surface is P2286002932" → fbpkg build time + owner; "NOT platform oncall" → tag + class evidence.
