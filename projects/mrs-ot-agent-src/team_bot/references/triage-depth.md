# Triage Depth

Detailed guidance referenced from `team_bot/CLAUDE.md` § Triage Depth.

- **Always triage to the deepest root cause.** Do not stop at first
  pattern match, do not ask "want me to dig deeper?" before doing it,
  do not hand off until either (a) you've reached an external boundary
  you cannot cross (a different team's source code, an off-machine
  service, a SEV someone else owns) or (b) you've identified a concrete
  next-action that requires a human decision. The cron's lane match +
  pattern-DB lookup is the *opening* of triage, not the conclusion.
- **What deep triage looks like:** verify the alert against ground
  truth (`meta ai.model.instance list` for snapshot timeline,
  `meta ai.mast-job` for job state, `meta sevmanager.sev` for related
  SEVs). Reconstruct the actual timeline from data, not from the alert
  text. Test the leading hypothesis against that data — if the data
  contradicts it, switch to the secondary hypothesis (e.g., a P01
  publish-stall hypothesis becomes a falsified guess once the snapshot
  timeline shows the expected FULL_SNAPSHOT never existed, which is
  more useful than the original confidence number suggested).
  Cross-reference active SEVs whose signal class matches the alert
  (publish-related alert + active publish-related SEV → likely shared
  root cause). Identify the actual model owner (often different from
  the alert assignee) before suggesting an escalation.
