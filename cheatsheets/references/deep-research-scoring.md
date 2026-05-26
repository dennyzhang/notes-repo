# Deep Research Quality Scoring

Each report is scored on 5 dimensions (0-2 points each, 10 total). Defaults are zero — earn each point.

| Dimension | 0 | 1 | 2 |
|-----------|---|---|---|
| **Novelty** | Restates wiki / first-page search results | Surfaces non-obvious details or connections | Reveals buried signals, contradictions, or gaps others missed |
| **Team Context** | Generic overview, no connection to our roadmap | References our org but vaguely | Maps findings to specific roadmap items, review docs, or team decisions |
| **Key Person Intel** | No people sourced | Names relevant people but no recent contributions cited | Cites specific TL/EM posts, decisions, or stated positions from last 90 days |
| **Actionability** | "This exists" | Suggests general direction | Names concrete next steps and who to talk to |
| **Source Depth** | Surface-level wiki/post summaries only | Loaded some primary sources (design docs, planning docs) | Synthesized primary sources with data (dashboards, metrics, SEV history) |

## Anti-Inflation Rules

- A report that only summarizes publicly available wikis/posts **caps at 4/10**
- **Key Person Intel** = 0 unless the report names specific people and cites their contributions from the last 90 days
- **Team Context** = 0 unless the report references a specific roadmap item, leads review doc, or team decision
- Self-assigned scores that violate these rules get auto-corrected downward

## Score Interpretation

| Score | What It Gets You |
|-------|-----------------|
| 0-3 | Surface-level summary — you know the topic exists but can't act on it |
| 4-6 | Meeting-ready — you can contribute meaningfully and ask informed questions |
| 7-8 | Strategic — you can identify gaps, propose actions, and influence direction |
| 9-10 | Exceptional — novel connections to team priorities with named next steps and key person context |
