# Hedwig Streaming — Flow Control Investigation

Read and follow the runbook at `fbcode/hedwig/download/docs/runbooks/streaming/flow_control_runbook.md`. It contains the full investigation workflow for flow control issues, publishing rate throttling, slow subscribers, slow P2P links, publishingRateDecider analysis, adaptive flow control debugging, and onboarding verification with typo detection (Step 3b).

For onboarding a new model to flow control, see [flow-control-onboarding.md](flow-control-onboarding.md) or `fbcode/hedwig/download/docs/runbooks/streaming/flow_control_onboarding.md`.

For grafting required flow control diffs onto a light_cli build, invoke the `hedwig-streaming-diff-graft` skill.
