# War Story #5 — MVAI Python Upgrade Leaks Memory During In-Trainer Publish (S669019)

**SEV:** S669019 — MVAI Python Upgrade causing OT jobs to OOM due to leak during in-trainer publish
**Level:** L3 | **Owner / journalist:** Li Lu (lupaul) | **Opened by:** Rehman Khan
**Diagnosis + mitigation:** Dave Kotfis (dkotfis)
**Duration:** May 28, 2026 → ongoing (In Progress as of 2026-06-10)
**GChat:** spaces/AAQA2NxeICM (`https://chat.google.com/room/AAQA2NxeICM`)
**Impact:** Various OT jobs OOMing across PGs (first/worst: Reels LSR MB9, `ig-reels-v2`). Memory-utilization chart shows **zero memory released over 24h** — a monotonic climb until the trainer is OOM-killed.

---

## The problem in one sentence

MVAI's platform-wide Python upgrade (3.10 → 3.12) introduced a memory leak in the `light_cli` trainer binary that manifests on the **in-trainer publish path** — every publish cycle leaks objects (BytesIO/tensor/string) that are never freed, so OT jobs climb to OOM with no memory released over 24h.

## Why this is the interesting one

The change that broke production was **not in any model's code, config, or data** — it was the language runtime underneath the trainer moving a version. This is the classic blind spot of change-delta triage: every per-model signal (job def, JK, checkpoint, data) looks unchanged, so "nothing changed" feels true. The real delta was the `light_cli` base binary being unpinned from CPython 3.10 (D102361451, part of the org `get us on to python 3.11/3.12` campaign, S653257). Runtime/toolchain/base-layer bumps are a first-class change-delta source — they just don't show up where you usually look.

## The diagnostic wall (the breakthrough)

The leak was **native** (jemalloc heap growth), but caused by **Python** allocations. Standard native heap profiles were useless: every stack truncated at `_PyEval_EvalFrameDefault` — the CPython eval loop — so the profiler could see "Python allocated this" but never *which* Python function. You cannot root-cause a Python-level leak with native-only profiling.

Breakthrough: dkotfis added opt-in **Strobelight PyAlloc hooks** (D107404124) to the light binary startup so jemalloc heap profiles capture Python interpreter frames, not just native frames — gated behind `MVAI_ENABLE_PYALLOC_HOOKS=1` + `MALLOC_CONF=prof:true`. Only then could the leaking allocations in the publish path be attributed to Python functions.

Causation was nailed by **isolating the single variable**: D107393121 rebuilt `light_cli:5719` with *only* the Python version reverted to 3.10 (nothing else changed). The leak disappeared → Python 3.12 confirmed as the cause, not any concurrent code change.

## Timeline

| When | Event |
|------|-------|
| (pre) | MVAI Python-upgrade campaign unpins `light_cli` from 3.10 (D102361451, Andrew Mao), driving toward 3.11/3.12 (S653257) |
| 2026-05-28 09:54 | S669019 opened (Rehman Khan): Reels LSR MB9 OT jobs OOMing across PGs; mem-util shows zero release in 24h; area `ig-reels-v2` |
| ~2026-06-02 | dkotfis adds PyAlloc hooks (D107404124) to see Python frames; builds py3.10-pinned test (D107393121) to isolate the variable |
| 2026-06-03 | Prevention follow-up T274198023 filed (Max Kaplan): instrument *all* MVAI OT jobs with Python Strobelight profiling |
| 2026-06 (rolling) | Mitigation: pin affected jobs back to py3.10 via TLS-config patches — Reels LSR MB9 LC / c6 / c8 (D107885118, D107897625, D107897791) |
| 2026-06-10 | Still In Progress (upstream py3.12 leak fix outstanding) |

## Root cause

CPython **3.12** in the `light_cli` trainer binary leaks on the in-trainer publish path — objects allocated each publish cycle (serialized BytesIO buffers / tensors / strings) are retained, so resident memory grows monotonically and the trainer is OOM-killed within ~24h. The trigger was the routine org Python-upgrade rollout; OT trainers, being long-lived processes that publish continuously, surface the per-cycle leak fastest.

## Mitigation (in flight)

Pin the affected OT jobs back to **Python 3.10** while the 3.12 leak is fixed upstream — `light_cli` py3.10 pin (D107393121) plus per-cell TLS-config patches for Reels LSR MB9 LC/c6/c8 (D107885118, D107897625, D107897791). This is a hold, not a cure: the org cannot stay on 3.10, so the real fix is the upstream interpreter/allocation leak.

## Prevention

**T274198023** (owner lupaul, target 2026-07-03) — instrument all MVAI OT jobs with Python Strobelight heap profiling *by default*. The diagnosis took as long as it did because OT jobs ship without Python-stack heap instrumentation; the next runtime-level leak should be diagnosable without an ad-hoc tooling diff first.

## Key artifacts

| Artifact | Link |
|----------|------|
| SEV | https://www.internalfb.com/sevmanager/view/669019 |
| MAST job (OOMing) | https://www.internalfb.com/mlhub/pipelines/runs/mast/mvai-training-online-2123013977 |
| Workplace report | https://fb.workplace.com/groups/254777643194247/permalink/1338967991441868/ |
| Workplace report (mrs.ot) | https://fb.workplace.com/groups/mrs.ot/posts/1347227230705353 |
| Diagnostic — PyAlloc hooks | https://www.internalfb.com/diff/D107404124 |
| Isolation — py3.10 pin test | https://www.internalfb.com/diff/D107393121 |
| Trigger — light_cli unpin 3.10 | https://www.internalfb.com/diff/D102361451 |
| Mitigation — TLS py3.10 patches | D107885118 · D107897625 · D107897791 |
| Prevention follow-up | https://www.internalfb.com/T274198023 |
| Related SEV (py upgrade) | S653257 |

## Core lessons

1. **A runtime/base-layer version bump IS a change-delta.** "No code/config/data changed" does not mean nothing changed — the interpreter, base layer, or toolchain under the trainer can move. Change-delta-first triage must explicitly check `light_cli`/base-layer/Python version against the symptom-onset time, not only app-layer signals.
2. **You can't root-cause a Python leak with native-only heap profiles** — stacks truncate at `_PyEval_EvalFrameDefault`. Python frame capture (Strobelight PyAlloc hooks) is mandatory; bake it into OT jobs by default (T274198023) so it isn't a per-incident scramble.
3. **Isolate one variable to prove causation.** Rebuilding the identical binary with only the Python version changed (D107393121) converted a strong hypothesis into proof. When a platform change is the suspect, pin-and-compare beats more profiling.
4. **Long-lived publishing OT trainers are the canary for per-cycle leaks.** A small per-publish leak is invisible in short batch jobs but fatal in a continuously-publishing OT job — OT will OOM first on any allocation regression in the publish path.

## Sourcing note

The SEV gchat space (`spaces/AAQA2NxeICM`) and `sevmanager.sev history` are **role-denied to the `myclaw` agent** (op=READ on CONFIDENTIAL). This narrative is reconstructed from `sevmanager.sev describe` (INTERNAL), the linked/mentioned diffs (D102361451, D107393121, D107404124, D107885118, D107897625, D107897791), and follow-up task T274198023 — **not** the chat transcript. Comment-level detail (18 SEV comments) and the human back-and-forth are not captured here; if the operator can paste the chat, the timeline and any false starts can be enriched.

## Failure family

Adds a fourth shape to the OT family catalog: **job running but OOMing (memory leak)** — distinct from job-stuck (S665454, S628346), training-on-nothing (S639956), and QPS-degrades (S668980). Here the trainer runs and trains correctly; it just bleeds memory until killed. The novel sub-class is *leak introduced by a platform runtime upgrade*, diagnosable only with Python-frame heap profiling.
