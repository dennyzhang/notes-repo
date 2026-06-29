# Hedwig OSS Peer (`hedwig-oss-peer`) Investigation

Read and follow the runbook at `fbcode/hedwig/download/docs/runbooks/downloads/oss_peer_runbook.md`. It covers two alarms for the OSS peer running in CKS clusters as the `s32m-cks-proxy` DaemonSet:

- **`Client success rate drop (OSS): hedwig-oss-peer`** — primary alarm; full agent investigation workflow (Steps A1–A6), decision tree, and kill-switch mitigation steps via Conveyor.
- **`Download digest mismatch (OSS): hedwig-oss-peer`** — secondary alarm; agent investigation workflow (Steps DA1–DA5) with hostname×file pivot classifier (bad-node vs upstream vs systemic) and per-cause mitigation.
