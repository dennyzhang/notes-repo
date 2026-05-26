# Daily Routine Workflow — Portable Claude Code Workflow

An overnight automation system that reads your calendar, career goals, people profiles, and org context — then writes a comprehensive daily action plan to a Google Doc before you wake up.

## What It Does

Every night at 2 AM, the routine workflow:
1. **Pre-fetches** GChat messages, calendar events, peer diffs, Workplace posts, SEV feeds, and oncall context
2. **Synthesizes** all signals through Claude into a structured daily plan with prioritized actions, coaching insights, diff reviews, and meeting prep
3. **Publishes** to a Google Doc (one section per day, preserving history) with validation scoring
4. **Self-evaluates** the output quality against configurable criteria and logs a score

## Architecture

```
Crontab (2:00 AM daily)
  │
  ├─ STEP 1: Parallel Data Pre-fetch (13 sub-tasks)
  │   ├─ GChat messages from configured spaces
  │   ├─ Calendar events for today
  │   ├─ Peer diffs (authored + reviewing)
  │   ├─ Workplace group posts
  │   ├─ SEV feed + oncall context
  │   ├─ Active project tasks
  │   ├─ Follow-up items due today
  │   └─ People profiles for meeting attendees
  │
  ├─ STEP 2: Claude LLM Synthesis
  │   └─ claude -p (mega-prompt + all pre-fetched data + template)
  │       → Structured daily plan with:
  │         • Action rows (what to do, priority, time estimate)
  │         • Coaching signals (IC score, ship rate, scope sprawl)
  │         • Diff review queue with review angles
  │         • Meeting prep with per-person context
  │         • Comms analysis (ask:tell ratio, reciprocity gaps)
  │
  ├─ STEP 3: Validation + Scoring
  │   └─ Python scorer checks: correct date, action count,
  │      goal references, coaching rows, meeting prep, word count
  │
  ├─ STEP 4: Google Doc Push
  │   └─ Prepend today's section (HTML) to the routine doc
  │       • Pre-push font lint + content lint
  │       • Format snapshot capture for consistency
  │       • Rollback-safe with pre-push revision pinning
  │
  └─ STEP 5: Self-Eval + Heartbeat
      ├─ LLM self-evaluation against workflow goals
      └─ Archive old entries (>14 days) to Archive tab
```

## Key Files You Need

| File | Purpose |
|------|---------|
| `routine-workflow.sh` | Main script — orchestrates the full pipeline |
| `routine-config.json` | Configuration: doc ID, GChat spaces, people list, career goals |
| `routine-template.md` | Prompt template: defines the output format Claude produces |

## Setup (30 min)

1. **Create a Google Doc** — this becomes your daily routine doc
2. **Copy `routine-config.json`** — fill in your Google Doc ID, GChat space IDs, calendar email
3. **Set up career context** — create `context/myself/IDENTITY.md` with your role, goals, weaknesses
4. **Create people profiles** — one `.md` file per key collaborator in `context/people/`
5. **Add to crontab**:
   ```
   0 2 * * * bash ~/work/claude/scripts/routine-workflow.sh >> ~/logs/routine.log 2>&1
   ```

## What Makes It Compound

Week 1 output is generic. By week 4, the routine:
- Knows your meeting patterns and preps per-person talking points
- Tracks your scope sprawl and warns before it gets out of control
- Catches communication gaps (ask:tell ratio, reciprocity)
- Connects today's work to your career goals
- Surfaces diff review opportunities aligned with your expertise

The key insight: **context accumulates**. People profiles, project history, and correction patterns all compound — each day's output is better than the last because the AI has more context to work with.

## Customization Points

- **Career goals**: Edit `IDENTITY.md` to change what the coaching section tracks
- **Scoring weights**: Adjust the Python scorer to match what matters to you
- **Action priorities**: Modify the prompt template to re-order priority rules
- **Data sources**: Add/remove pre-fetch steps based on your org's tools
- **Output format**: Change the HTML template to match your preferred doc layout

## Requirements

- Claude Code CLI (`claude -p` for non-interactive mode)
- Google Docs API access (via `google-mux` or similar)
- GChat API access (for message pre-fetching)
- Calendar API access (for meeting context)
- Crontab or equivalent scheduler

## Example Output

A typical daily routine section includes:
- 3-5 prioritized action rows with time estimates
- IC score assessment (are you making decisions or just executing?)
- 5-8 diffs in your review queue with review angles
- Meeting prep for each meeting with per-person context
- Comms analysis with specific improvement suggestions

## Related Workflows

- [Area Monitor](https://www.internalfb.com/code/notes/users/dennyzhang/sharings-public/area-monitor-portable/) — overnight org intelligence gathering
- [Morning Digest](routine-workflow.sh) — comprehensive GChat briefing from all docs
