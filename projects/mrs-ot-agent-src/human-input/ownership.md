# Component Ownership and Agent Code

Each team owns a pipeline stage. Teams should add pointers to their agent/skill code here.

| Stage | Component | Team | Key Contact | Agent/Skill Code | Oncall |
|-------|-----------|------|-------------|------------------|--------|
| T1 | Scribe / DPP | DPP/MLDP | Nasrin Jaleel | *TODO: add pointer* | mldp_oncall |
| T2 | Training / MVAI | MVAI | Li Lu | [mvai-ot/reliability/](https://www.internalfb.com/code/fbsource/fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/) | mrs_online_training |
| — | TMS (Job Orchestration) | AI Infra | Paul Lu | mvai-ot/reliability/diagnostics/tms-launch-errors.md | managed_training_service |
| T3 | Publishing / SilverTorch | SilverTorch | Shuguang Ye, Ziqi Liu | [silvertorch-item-freshness](https://www.internalfb.com/claude-templates/plugins/silvertorch-item-freshness) | home_ml_platform |
| T4a | Serving / Recsys | Recsys/IP Runtime | Hongbo Qin | [investigate-success-rate/](https://www.internalfb.com/code/fbsource/fbcode/ip_runtime/model_freshness/operation/streaming/investigate-success-rate/) | ip_runtime |
| T4b | Streaming / Hedwig | Hedwig | Qiuyu Xiao | *TODO: add pointer* | hedwig |
| — | Monitoring / PE (this is us) | PE MRS | Denny Zhang, Paul Lu | this skill | mrs_online_training |
| — | Data Science (advisory) | AI Infra DS | Jessica Wang | *TODO: add pointer* | — |

## Existing MVAI OT Reliability Skill (T2/T3 deep triage)

The master agent delegates T2/T3 deep dives to this existing skill (18 files):

| File | Purpose |
|------|---------|
| [triage.md](https://www.internalfb.com/code/fbsource/fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/workflows/triage.md) | SEV triage workflow (IDENTIFY → LOCATE → INVESTIGATE → RESOLVE) |
| [monitoring.md](https://www.internalfb.com/code/fbsource/fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/operations/monitoring.md) | Publishing alert analysis, delta status verification |
| [knowledge.md](https://www.internalfb.com/code/fbsource/fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/reference/knowledge.md) | 20+ real SEV patterns with root cause analysis |
| [dashboards.md](https://www.internalfb.com/code/fbsource/fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/operations/dashboards.md) | All dashboards and escalation contacts |
| [log_analyzer.md](https://www.internalfb.com/code/fbsource/fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/diagnostics/log_analyzer.md) | MAST job log analysis patterns |
| [architecture.md](https://www.internalfb.com/code/fbsource/fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/reference/architecture.md) | OT architecture and data flow |
| [cli.md](https://www.internalfb.com/code/fbsource/fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/operations/cli.md) | Full CLI command reference |
| [live-sev.md](https://www.internalfb.com/code/fbsource/fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/workflows/live-sev.md) | First 5 minutes of live SEV response |

## Delegation — How This Skill Routes to Component Skills

| Component Issue | Delegated To | What They Own |
|----------------|-------------|---------------|
| Trainer crash, deadlock, NE regression | [mvai-ot/reliability/workflows/triage.md](https://www.internalfb.com/code/fbsource/fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/workflows/triage.md) | Root cause analysis, checkpoint recovery, revert-and-ban |
| Publishing stall, snapshot health | [mvai-ot/reliability/operations/monitoring.md](https://www.internalfb.com/code/fbsource/fbcode/minimal_viable_ai/agent/skills/mvai-ot/reliability/operations/monitoring.md) | GMPP logs, publish mode diagnosis |
| TMS job orchestration | TMS oncall (managed_training_service) | Auto-restart, registration, fbpkg lifecycle |
| Scribe/DPP data pipeline | DPP oncall (mldp_oncall) | Scribe delay, example age, data freshness |
| Hedwig streaming | Hedwig oncall (hedwig) | Message delivery, flow control, rate limits |
| Predictor/serving | Recsys oncall (ip_runtime) | Weight manager, snapshot transition, update rate |

If a team has an existing Claude skill, the master agent loads it for deep-dive analysis. If not, it routes to the human oncall with evidence.
