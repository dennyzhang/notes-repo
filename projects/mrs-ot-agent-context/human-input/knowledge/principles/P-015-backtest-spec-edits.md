# P-015: Backtest Spec Edits Before Shipping

**Statement:** After editing a durable spec (cron prompt, lint rule, archive format), run the spec MANUALLY against ≥1 representative data point BEFORE pushing. Diff-of-spec ≠ behavior-of-spec.

**Discovered:** 2026-05-17 thread `Uc-pVBEXNQ8` 11:18 PT — operator asked "have you backtest the alerts for the new changes?" after I shipped R20 local-archive sweep. Backtest immediately exposed 2 latent bugs (missing mega-learnings/ source, missing INDEX.md exclusion).

**Why it matters:** Spec edits look correct in isolation but interact with real data in ways the editor didn't anticipate. Cross-references in archives, auto-generated files, regex anchoring, path variants — all surface only when you execute the spec on real input. 2 out of 3 of my 11:00-11:15 PT silent failures were caught by backtest (self) or operator (1 case); each costs ~1 operator round-trip if uncaught.

**Applies to:** any agent editing durable specs that fire autonomously (cron prompts, lint regexes, archive templates).

**Current applications:**
- ot-prompt-change-validator cron (every 10min sub-agent simulation against past raw_response — automated backtest)
- Manual backtest after each spec edit (operationalized 2026-05-17 11:18 PT)
- Backtest checklist: pick 1 model with KNOWN prior data + 1 model with NO prior data; verify both produce expected output

**Anti-patterns it prevents:**
- 2026-05-17 11:15 PT: R20 local-sweep shipped without backtest; missed mega-learnings/ + INDEX exclusion (caught by operator's 11:18 PT prompt → backtest revealed 2 bugs)
- 2026-05-17 11:06 PT: bulk-classify shipped pass-1 without spot-check; content-grep produced cross-ref false positives (self-caught at spot-check, before push)

**Procedure (operationalize):**
1. Identify ≥1 representative input the spec will operate on (a real archive, model_id, alert)
2. Mentally walk through the spec OR run the literal commands the spec describes
3. Check output matches expectations across BOTH happy-path (rich data) AND empty-path (no data)
4. Look for false positives (auto-gen files, cross-references, self-matches)
5. Only then commit + push

**Related principles:** P-002 (shipping requires execution — backtest is HOW you execute), P-009 (validator coverage asymptotic — each operator catch grows the checklist), P-011 (spec vs lint — backtest validates BOTH spec AND lint coverage)
