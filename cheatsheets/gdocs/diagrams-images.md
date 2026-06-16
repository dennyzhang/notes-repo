# Diagrams & images in docs (markdown + gdoc) — readability gate

Recurring miss: diagrams render **too small / thin-strip** and are illegible. Prose
reminders get skipped under task focus → make it an **executable gate** (operator
principle: "prose lints need an executable gate").

## The gate
`mrs-ot-agent-src/tools/lint-doc-images.sh <file.md>` — fails if any embedded image is
< 900px wide, < 300px tall, or aspect ratio > 3:1 (thin strip). Run it before committing
any markdown that embeds an image. Wire it into md write/commit paths.

## Rendering rules (so the default output passes)
- **Graphviz:** `rankdir=TB` for width-constrained docs (LR produces wide-thin strips that
  shrink to nothing); `dpi=150–180`; readable `fontsize`. **Always `file <img.png>` after
  rendering** to confirm dimensions (target ≳1000px on the long side, aspect ≤ 3:1).
- **Aspect ratio is the usual culprit:** a 1900x295 image (aspect 6.4) renders tiny on a
  page; the same graph in TB at 1876x1289 is readable. Reorient before bumping dpi.
- **gdoc image insert:** set an explicit width (don't accept the tiny default); verify it
  renders at a readable size in the doc, not just that the insert succeeded.

## Source files
- Keep diagram **source** (`.dot`, `.js`) in `~/.myclaw-ot-bot/` — the notes repo strips
  `.dot`/`.js` (stalls auto-push). Commit only the rendered `.png` (+ `.txt` mirrors).
- Regen: `dot -Tpng x.dot -o x.png` then `cp` the png into the notes tree.

## CLUTTER is the enemy, not width (2026-06-12 — corrected after several wrong guesses)
The recurring "image too small / hard to follow" was NOT a width problem. The operator's doc viewer
renders images at **full size in a wide column**, so:
- **WIDE landscape is GOOD** — it fills the column. Do NOT narrow for narrowness (I wasted iterations
  shrinking to 1052px; that just left it small with whitespace). An earlier "too-wide" gate rule was
  WRONG and was reverted.
- **The real fix is SIMPLICITY:** few boxes (~5), a clean linear top-to-bottom flow, **ONE** feedback
  arrow. The version that worked: a numbered `1 Incidents → 2 Triage+self-audit → 3 Distill →
  4 ★EVAL keep-winners → 5 Commit→smarter`, one loop arrow. A 9-box diagram with 6 crossing edges
  (recheck/reject/recalibrate/corrections/…) is "slow to follow" — push that detail into the README
  text, not the picture.
- **Big fonts** (≥26pt) so it's legible; **`dpi` is a no-op** for readability.
- **No thin strips:** a linear chain in `rankdir=LR` (or too many boxes) becomes a wide-thin strip
  (aspect ≫3) — also bad. Keep aspect ≤ ~3 (TB vertical flow is the safe default).
- Graphviz can't render emoji → tofu boxes. Use plain text + fill color.
- Gate (`lint-doc-images.sh`) enforces: min 900x300px + aspect ≤3 (no thin strips). It does NOT cap
  width (wide is fine). Clutter can't be linted — keep it simple by hand.

## How to give this feedback so it sticks (meta)
Don't re-state "too small" each time → (1) the **gate** above catches it mechanically (now incl. too-wide),
(2) this cheatsheet is the reference, (3) memory `feedback_diagrams-must-be-readable`
recalls it. Same pattern as `shift-doc-lint.sh`.

Last updated: 2026-06-12
