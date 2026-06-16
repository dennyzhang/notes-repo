# Agents & Automation Cheatsheets

Building & running AI agents and automations (bots, crons, hooks, evals, MyClaw).
Design philosophy + operations. (Harness wiring lives in `system/`.)

| When | Load |
|------|------|
| Designing prompts/classifiers/hooks/automations (pressure → suppressed behavior) | `agents/agent-pressure.md` |
| Coaching the operator to give better prompts (detect repetition, ambiguity, suppressing framing) | `agents/prompt-coaching.md` |
| Recurring AI mistakes to avoid (load before non-trivial work) | `agents/ai-failure-modes.md` |
| Building any hook / cron / workflow | `agents/workflow-design.md` |
| Autonomous workflow design (output density, correctness, safety, durability) | `agents/autonomous-workflow-principles.md` |
| Closing a topic/thread — save & route session learnings | `agents/auto-save-learnings.md` |
| Improving/adding cheatsheets (gate, tier policy, skill-harvest, anti-bloat) | `agents/cheatsheet-flywheel.md` |
| Building agent evals (replay-eval, scoring harness) | `agents/building-agent-evals.md` |
| MyClaw ops: disk full, worktree leaks, instance management | `agents/myclaw-ops.md` |
| Deleting a MyClaw instance | `agents/myclaw-delete.md` |
