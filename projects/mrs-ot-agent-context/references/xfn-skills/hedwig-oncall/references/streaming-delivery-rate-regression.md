# Hedwig Streaming Delivery Rate Regression Investigation

Read and follow the runbook at `fbcode/hedwig/download/docs/runbooks/streaming/streaming-delivery-rate-regression.md`. It contains the full investigation workflow, ODS/Scuba commands, decision tree, output format, and root cause categories.

This runbook is for investigating **SLI-level delivery rate regressions** across all clients (aggregate regression). For investigating a **specific model's** streaming success rate, use `streaming-success-rate.md` instead.

Before starting, gather from the user:
- **time_range** (optional): Time range to investigate (defaults to last 6 hours)
- **client_id** (optional): Specific client to focus on (e.g., "ADINDEXER")
- **region** (optional): Specific region to focus on
