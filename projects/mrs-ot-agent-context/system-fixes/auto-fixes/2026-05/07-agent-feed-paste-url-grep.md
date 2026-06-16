```yaml
fix_id: agent-feed-paste-url-grep
title: When SEV agent-feed contains operator paste URLs, paste = canonical RCA (overrides Opsmate)
status: 🟡 drafted
identified: 2026-05-20 thread 2wDCp51dUxE (S665454 triage debug)
target: team_bot/cron-jobs/ot-sev-monitor.md
section: SEV → root cause derivation
impact: Eliminates conflict between Opsmate auto-analysis and operator-written RCA
cost: ~5-line cron prompt amendment
```

## Gap

For S665454 (Threads Retrieval U2M), cron derived "bloom_index_b deadlock" from Opsmate. The REAL root cause was operator-written paste P2341568201 (Li Lu's analysis: CUDACachingAllocator INTERNAL ASSERT + Elastic Agent D-state hang). The paste is canonical; Opsmate was wrong / partial.

## Patch

### Before

```
Pull SEV root cause from:
  - SEV form fields
  - Opsmate Investigator agent-feed entry
```

### After

```
SEV ROOT CAUSE DERIVATION — PASTE URLS OVERRIDE OPSMATE:

  1. Pull SEV agent-feed: meta sevmanager.agent-feed list --sev=<num> --no-truncate

  2. Grep agent-feed body for paste URLs: regex `/intern/paste/P\d+`
     For each found:
       - Pull the paste content: meta url.load lookup --input=<url> --raw
       - Treat the paste as OPERATOR-WRITTEN CANONICAL RCA

  3. If paste URL exists with substantive RCA content:
       - Adopt the paste's root cause as authoritative
       - Note Opsmate's analysis as "Opsmate inferred X; operator paste
         P##### corrects to Y"
       - Do NOT silently let Opsmate dominate

  4. ALSO grep agent-feed for thread URLs (chat.google.com/...) — operator
     discussion threads contain RCA when paste URLs don't
     (NB: bot may lack gchat access — see 14-sev-chat-via-meta-cli.md)

  5. Form fields (overview, root_cause) are LAST resort — operators
     rarely fill them. Don't rely on them being populated.

PRIORITY ORDER for RCA evidence:
  1. Operator-written paste URL in agent-feed (highest priority)
  2. Operator-written comments in SEV chat (via meta sevmanager.chat list)
  3. Opsmate Investigator agent-feed entry (auto-generated, sometimes wrong)
  4. Similar SEVs Agent linkage (Medium-confidence cluster signal)
  5. SEV form fields (often empty)
  6. SEV title regex inference (last resort)
```

## Triggering evidence

- 2026-05-20 thread 2wDCp51dUxE — S665454 P2341568201 (Li Lu's analysis) was canonical truth; bot's prior reliance on Opsmate produced wrong root cause

## Validation

- [ ] Audit 20 SEV triages over 7d; for any SEV with paste URL in agent-feed, paste content was consulted
- [ ] Apply to historical SEVs from resolved-sevs/ with paste URLs; verify root cause attribution matches paste

## Related

- `IMPROVEMENT-PROPOSALS.md` Proposal F discipline gap (SEV chat-access blind spot)
- `14-sev-chat-via-meta-cli.md` (companion fix for SEV chat access)
