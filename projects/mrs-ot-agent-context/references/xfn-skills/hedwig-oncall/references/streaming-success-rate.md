# Hedwig Streaming Success Rate Investigation

Read and follow the runbook at `fbcode/hedwig/download/docs/runbooks/streaming/model_streaming_success_rate_runbook.md`. It contains the full investigation workflow, ODS/Scuba commands, decision tree, output format, and flow control guidance.

**Important:** When the investigation points to publishing rate issues (publisher queue growing), the primary recommendation is to **onboard to flow control** — NOT to manually increase the publishing rate. Manual rate increase is only for legacy light_cli builds before December 2024. See the [Flow Control Onboarding Guide](flow-control-onboarding.md) or `fbcode/hedwig/download/docs/runbooks/streaming/flow_control_onboarding.md`.

Before starting, gather from the user:
- **model_id** (required): Model series ID (e.g., "879943520")
- **model_type** (optional): "sparse" (default) or "ebd"
- **region** (optional): Affected region
- **time_range** (optional): defaults to last 6 hours

If the user only provides a publisher-side MAST job ID, derive `model_id` first using the **Publisher-Side Lookup** in [debugging-tools.md](debugging-tools.md#publisher-side-lookup-mast-job--tw-job--client_id--model_id). The agent path uses the `mast` CLI (`get-job-definition` + `get-tw-job-spec`) to find the backing TW job name without needing the MLHub UI; the human path opens the MLHub page. Then filter `hedwig_streaming_investigator` by `tw_job` and read `model_id` from the `file` column.
