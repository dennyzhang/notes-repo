# Impact Anti-Patterns

Common mistakes that undermine impact claims. Use as a checklist when writing PSCs, one-pagers, or framing SEV contributions.

## Activity vs. Outcome

| Activity (Weak) | Outcome (Strong) |
|-----------------|------------------|
| "Worked on the profiler project" | "Shipped profiler, reducing debug time 80%" |
| "Wrote 5,000 lines of code" | "Delivered feature used by 10K users/day" |
| "Attended 20 meetings" | "Aligned 3 teams on shared roadmap" |
| "Reviewed 50 diffs" | "Caught 3 critical bugs before production" |
| "Spent 2 weeks debugging" | "Root-caused SEV, preventing $500K/year in incidents" |

**Fix:** Always answer "So what?" after describing activity.

## Vanity Metrics

| Vanity Metric | Why It's Weak | Better Metric |
|---------------|---------------|---------------|
| "Processed 1B requests" | Volume does not equal value | "Cost per request reduced 30%" |
| "99.9% uptime" | Expected, not exceptional | "Improved from 99.5% to 99.9% (4x fewer incidents)" |
| "10K lines of code" | More code = more maintenance | "Shipped feature in 2K lines (5x less than alternative)" |
| "Used by 100 engineers" | Adoption does not equal impact | "Saved 100 engineers 2 hours/week each" |

**Fix:** Ask "Does this number measure business/technical value?"

## Vague Impact Claims

| Vague Claim | Quantified Version |
|-------------|-------------------|
| "Improved reliability" | "Reduced failures from 5% to 0.5%" |
| "Faster deployments" | "Deploy time: 4 hours to 15 minutes" |
| "Better developer experience" | "Setup time reduced 80% (2 days to 4 hours)" |
| "More efficient" | "40% less compute, same throughput" |
| "Significant impact" | [Specific number] |

**Fix:** Replace every adjective with a number.

## Credit Without Contribution

| Anti-Pattern | Honest Version |
|--------------|----------------|
| "We shipped X" (when you did little) | "I contributed Y to the team's X effort" |
| "My project saved $1M" (team of 10) | "Led component that drove 30% of savings" |
| "I fixed the SEV" (you ran a command) | "Executed mitigation per oncall runbook" |

**Fix:** Describe your specific contribution, then team context.

## Effort Justification

| Effort Claim | Impact Version |
|--------------|----------------|
| "I worked 60-hour weeks" | "Delivered X under tight deadline" |
| "This was really hard" | "Solved problem that blocked 3 teams" |
| "I've been heads-down on this" | "Shipped 3 features this quarter" |

**Fix:** Measure output, not input.

## Future Impact Inflation

| Inflated Claim | Honest Version |
|----------------|----------------|
| "Will save $5M/year" | "Expected to save $5M/year; currently in pilot" |
| "When adopted, will reduce..." | "Pilot shows X; full rollout projected by [date]" |

**Fix:** Distinguish delivered vs. projected. State confidence level.

## Missing Baseline

| No Baseline | With Baseline |
|-------------|---------------|
| "Reduced latency to 50ms" | "Reduced latency from 200ms to 50ms (75%)" |
| "Achieved 99.9% uptime" | "Improved from 99% to 99.9% (10x fewer incidents)" |

**Fix:** Always state before and after.

## Self-Assessment Checklist

Before claiming impact, verify:

| Check | Question |
|-------|----------|
| Quantified | Is there a number? |
| Baselined | Before vs. after? |
| Attributed | Your specific contribution? |
| Verified | Measured, not estimated? |
| Sustained | Still true after time passed? |
| Relevant | Tied to business/team goals? |
| Honest | Would your peers agree? |

## Quick Fixes

| If You Wrote... | Replace With... |
|-----------------|-----------------|
| "Worked on" | "Shipped" / "Delivered" / "Launched" |
| "Helped with" | "Contributed X to" / "Owned Y portion of" |
| "Improved" | "[X]% improvement from Y to Z" |
| "Significant" | [Specific number] |
| "Various" | [List the specific items] |
| "Multiple" | [Exact count] |
