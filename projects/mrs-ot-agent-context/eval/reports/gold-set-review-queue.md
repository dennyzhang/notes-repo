# Gold-set review queue (2026-06-12)

_Optional human AUDIT of the eval's ground truth — the lifecycle is auto-curated (curator); this just spot-checks it (Key challenge #2). **17/77** cases flagged — LEAK 17 · THIN-RC 0. Score-blind, read-only: approve/correct/drop in `gold-set.json` yourself; the loop never blocks on this. LEAK first (it poisons the eval), then THIN-RC (may be mislabeled)._

| case | type | flags | p_row | root_cause (ground truth) |
|---|---|---|---|---|
| ALERT-1002291152283272 | alert | **LEAK** "s667358 (ig relevance t20 h100 scribe" | P57 | DETECTOR_BROKEN + UPSTREAM_INFRA: SPARSE_DELTA detector is misconfigured for a retrieval |
| ALERT-1011200521237714-2026-05-18 | alert | **LEAK** "running 11+ days, publishing every 45" | CL-013 | THRESHOLD_MISFIT — Scuba formula bug: timezone mismatch (D75703936) + wrong scope for _r |
| ALERT-1021144657237695 | alert | **LEAK** "s665114 ws zippydb flash bandwidth quota" | CL-003 (P50 falsified) | 25 active ZippyDB SEVs (chief S665114 WS ZippyDB Flash Bandwidth Quota Low) elevated scr |
| ALERT-1421314379760011 | alert | **LEAK** "s668542 (feed scribe quota exhaustion, 2.797" | CL-003 / P57 | P57 match — AGG rule bundling scribe_read_proxy.client_lag_in_seconds sub-firings during |
| ALERT-1621571482326635 | alert | **LEAK** "zippydb s665114 (flash bandwidth quota low" | CL-003 / R16 | CL-003 UPSTREAM_INFRA — ZippyDB S665114 (Flash Bandwidth Quota Low ATG0) depressed Scrib |
| ALERT-1946819640036823 | alert | **LEAK** "s668542 (feed scribe quota exhausted, l4," | — | Upstream ZippyDB/Scribe degradation driving scribe_read_proxy lag across multiple IG OT  |
| ALERT-2130305043-AGG | alert | **LEAK** "s654082 zippydb ai training flash write" | UPSTREAM_INFRA | S654082 ZippyDB AI training flash write overload (In Progress since 2026-04-23) caused s |
| ALERT-2449443538836650 | alert | **LEAK** "zippydb ai training flash write overload" | P57 | UPSTREAM_INFRA: scribe_read_proxy client_lag elevated during ongoing ZippyDB/Scribe pres |
| ALERT-25997363823253100 | alert | **LEAK** "s668542 feed scribe quota exhaustion (>302h" | — | S668542 Feed Scribe quota exhaustion (>302h In Progress, 2.797 TB/s > 2.66 TB/s quota) + |
| POST-1326387856122624 | post | **LEAK** "sjd did not detect the job" | P21 | Elastic agent error handling: when the job errored at 11pm, the elastic agent failed to  |
| POST-1337733828321360 | post | **LEAK** "and preserve an ephemeral app-layer package." | — | ACL access not provisioned for msgr_eng_product_intelligence_temp and videorecs_reels_pr |
| S607776 | sev | **LEAK** "set to alert_only and did not" | — | Bias explosion in embedding_feature_modules.linear_modules.2 layer during training (sudd |
| S649277 | sev | **LEAK** "examples older than 5 minutes were" | — | DPP rolled out D100836039, intended to apply training-data age capping only to models wi |
| S665707 | sev | **LEAK** "on i7_xlarge workers during buck2 x86" | — | Sandcastle OOM on I7_XLARGE workers during buck2 x86 compilation of light_cli; oomd kill |
| W1324864999608243 | post | **LEAK** "across 2 regions and 9 restart" | none | _preload_item_pool() in ig_retrieval/trainer.py blocks the DPP consumer thread during ch |
| W1332798372148239 | post | **LEAK** "dpp automatically restarts each ot job's" | none | DPP data session TTL of 1728000 seconds (~20 days) expires; DPP automatically restarts e |
| W1337733828321360 | post | **LEAK** "to commit in the relevant code" | none | ACL access not provisioned for the two oncalls to commit in the relevant code path and p |
