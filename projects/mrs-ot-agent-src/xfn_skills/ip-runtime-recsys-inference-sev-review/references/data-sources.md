# Data Sources, Groups, Wikis & Experts

Load this reference when looking up specific URLs, dashboards, workplace groups, wiki documentation, or domain experts.

## Table of Contents

- [Key Data Sources](#key-data-sources)
- [Key Workplace Groups](#key-workplace-groups)
- [Key Wikis & Documentation](#key-wikis--documentation)
- [Reference Experts](#reference-experts)

## Key Data Sources

| Source | URL Pattern | Purpose |
|--------|-------------|---------|
| SEV Manager | `https://www.internalfb.com/sevmanager/view/{sev_id}` | Primary source of truth |
| MLHub Model Management | `https://www.internalfb.com/mlhub/model_management/ip_service/{tenant_id}` | Model config, snapshot history |
| Scuba - Runtime Freshness | `https://fburl.com/scuba/runtime_freshness/` | Snapshot transition monitoring |
| Scuba - IPNext Model Lifecycle | `https://fburl.com/scuba/ipnext_model_lifecycle/` | Model lifecycle events |
| Scuba - Service Router | `https://fburl.com/scuba/service_router/` | Error rates, latency metrics |
| Scuba - Sigrid Bad Requests | `https://fburl.com/scuba/sigrid_predictor_bad_requests/` | Bad request recording |
| Logarithm | Log search | Predictor warmup timing, GPU errors, binary version |
| Vanguard | `https://www.internalfb.com/vanguard/` | Serving test cases for binary validation |
| OneDetection | Alert system | Alert history and thresholds |

## Key Workplace Groups

- **Inference Platform Users**: https://fb.workplace.com/groups/inferenceusers -- User-reported issues
- **Inference Platform (Predictor) Oncall**: https://fb.workplace.com/groups/117294632482265 -- Oncall summaries
- **MRS ML SEV Review Discussion**: https://fb.workplace.com/groups/588293406548794 -- SEV review prep
- **AI Inference SEV Review**: https://fb.workplace.com/groups/628006595131899 -- Cross-team SEV reviews
- **RecSys Inference Serving Team**: https://fb.workplace.com/groups/25213031591696441 -- Team updates
- **GPU Debugging Engineering**: https://fb.workplace.com/groups/642870248426480 -- GPU debugging tools

## Key Wikis & Documentation

- **Runtime Common User Questions**: https://www.internalfb.com/wiki/Inference/Inference:_Internal/Teams/RecSys_Runtime_Team/Historical_Notes/Runtime_Common_User_Question/
- **Snapshot Transition Concepts**: https://www.internalfb.com/wiki/Inference/Inference:_Internal/Teams/IPnext:_Serving_Pillar/IPnext:Solutions/Operational/IPnext_Solutions_Oncall_Runbooks/Snapshot_Transition_Runbook/Snapshot_Transition:_Concepts/
- **IFR ESR IPNext Troubleshooting**: https://www.internalfb.com/wiki/Multifeed/Recommendation/IFR_New_Oncall_Runbook/IFR_ESR_Oncall_Guidance/IFR_ESR_IPNext_Service_Troubleshooting_Guide/
- **AMD Performance Tuning Guide**: https://www.internalfb.com/wiki/AMD_Performance_Tuning_Guide/
- **Multi-Forward Inference**: https://www.internalfb.com/wiki/Inference/Inference:_Internal/Teams/RecSys_Runtime_Team/Sigrid_Predictor/IRNext_(IP_Runtime_Next)/Multi-Forward_(Multi-Method)_Inference_within_Sigrid/

## Reference Experts

| Unix Name | Domain |
|-----------|--------|
| manishr | IP Runtime Serving, binary revert/unpinning |
| joshuasu | IP Runtime oncall, warmup/snapshot transition |
| hongbo1001 | Binary release, AOTI |
| rihu | Binary oncall, revert procedures |
| wanyunluc | Runtime freshness monitoring |
| bagrawal | AMD debug agent, GPU debugging |
| ttli | Local reproduction, binary bisection |
| algo | TW crash investigation |
