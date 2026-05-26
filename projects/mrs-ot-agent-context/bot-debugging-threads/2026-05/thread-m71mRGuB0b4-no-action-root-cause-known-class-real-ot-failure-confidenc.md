# Thread Summary: NaN triage + IFR prod trainer disambiguation + QE/prod signals + "preprod" terminology

_Source: spaces/AAQAVOjYc80 thread `m71mRGuB0b4` · 29 messages · 2026-05-19 19:48–22:36 PDT_
_Summarized: 2026-05-19 23:42 PT · last-msg-time: 2026-05-19T22:36:03Z_

## What was discussed

Thread covered three distinct topics. (1) Cron triage audit for model 878858380 (facebook_cfr_hstu_online): sub-metric 4/4 of a NaN cascade fan-out, auto-resolved; cron's verdict correct but has a persistent TZ-labeling bug (PDT timestamps labeled as UTC). (2) R-VC4 family-level escalation question for facebook_cfr_main_mtml: 6+ NaN events/48h across 2 models; bot asked Denny whether to file SEV, Denny deferred (bot doesn't auto-file cross-team SEVs). (3) Hands-on investigation of prod trainer for `facebook_ifr_main_umia_v1_mvai`, resulting in two corrections and several durable heuristics for model disambiguation.

## Key decisions made

- **2026-05-19 19:49:28**: Cron verdict (NO ACTION, CL-017) correct; TZ-labeling bug (Bug B) flagged for auditor R-EV1b.
- **2026-05-19 20:27:23**: Bot confirmed R-VC4 breach (≥5 NaN/24h, ≥2 model_ids) but will NOT auto-file family SEV; operator decides.
- **2026-05-19 21:40:01** (Denny correction): `mvai-training-online-2126481789` (chunhuigu) is the prod root trainer — confirmed by STUS `MVAI_MODEL_IDS=root:2126481789`. `882278521` (kxu42) is NOT; has zero STUS consumers. Bot's initial checkpoint-maturity heuristic gave the wrong answer.
- **2026-05-19 22:22:08** (Denny: read Anthony Foiani's thread): AIM cconf is source of truth for baseline/candidate/holdout classification; "preprod" is not a real term — use "launch candidate." Single inference model_id can have ≥2 OT jobs (root trainer + inference model trainer).
- **2026-05-19 22:35:46**: `fbpkg versions <pkg> --show-deleted` required to find GC'd versions (`:2038` was invisible without the flag because it was already deleted).

## Files / artifacts touched

(none written directly in this thread)

## Cluster / pattern references

- [CL-017] — Shampoo NaN on facebook_cfr_main_mtml; 878858380 sub-metric 4/4 fan-out from parent A25209897055308328; out-of-scope (model-side), routed via R21

## Followup items (not yet done)

1. Implement R-EV1b (auditor rule: do not re-label PDT CLI timestamps as UTC) — queued to weekly batch
2. Implement R-XX (MVAI_MODEL_IDS reverse-lookup for prod-trainer ID, not checkpoint-maturity heuristic) — queued to weekly batch
3. Implement R-QE (QE-vs-prod pre-triage gate using entitlement + TIER + STUS reverse-lookup) — queued to weekly batch
4. Update triage vocab: drop "prod/preprod", use baseline/candidate/holdout — queued to weekly batch
5. Denny to decide whether to file family-level SEV for facebook_cfr_main_mtml R-VC4 breach

## Cross-refs

- SEVs discussed: S665902 (Conveyor regression, facebook_cfr_main_mtml 878858380, active), S663572 (NE quality 2134319967)
- Related threads: `2w5Schmk83U` (same auditor/cron discussion), `9vLqtKbImwQ` (S665521, "leave to POC" SEV filing rule), `4u3oOvwSD30` (CL-017 moved to out-of-scope)
