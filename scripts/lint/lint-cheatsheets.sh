#!/usr/bin/env bash
# lint-cheatsheets.sh — Structural health-check for the cheatsheet tree.
#
# Content discipline (dated evidence, >=3-entry inclusion bars, hook coupling)
# is already strong; this guards the *structural* axis that drifts silently:
#
#   1. SIZE       files over the 800-line cap stated in CHEATSHEET-INDEX.md.
#   2. PROVENANCE files with no "Last updated:" marker (reader/agent can't tell
#                 fresh from stale). --stamp prints ready-to-paste footers with
#                 the real last-commit date from `sl` (verifiable, not invented).
#   3. LINKS      relative markdown links [t](foo.md) / (foo.md#anchor) whose
#                 target file (or #anchor heading) does not exist.
#   4. ORPHANS    content .md files referenced by no other .md (dead files).
#   5. INDEX      the "Files" count column in CHEATSHEET-INDEX.md drifting from
#                 the actual per-folder *.md count (excluding INDEX.md).
#
# MODES
#   (default)        full audit, human report.   exit 0 clean / 1 findings / 2 bug
#   --stamp          print "<file>\t<footer>" (real sl date) for files missing
#                    provenance. Does NOT write.
#   --fix-index      auto-heal the INDEX "Files" counts from the real per-folder
#                    *.md count. Deterministic + reversible (auto-fix tier).
#   --gate FILE...   COMMIT GATE. Fail-closed ONLY on what a single edit can fix
#                    on the given files: missing provenance footer, newly-broken
#                    link, and a NEW rule bullet added to a CORE cheatsheet
#                    (CORE_RULE_FILES) without a learnings-log entry in the same
#                    commit (override: CHEATSHEET_RULE_OK=1). Size = non-blocking
#                    WARN (pre-existing debt must not brick the 4-hourly
#                    auto-push). Orphans not checked (needs whole-tree view).
#                    exit 0 pass / 1 block / 2 bug.
#
# Default ROOT: ~/notes/users/dennyzhang/cheatsheets
set +e  # fail-open

ROOT="${ROOT:-$HOME/notes/users/dennyzhang/cheatsheets}"
CAP=800
# Hot-path "core" cheatsheets (loaded before a task). Adding a NEW rule bullet to
# one of these must ship with a learnings-log entry in the SAME commit — the
# enforceable proxy for the close-thread "log evidence, promote only after >=3"
# doctrine (a hook can't semantically verify the count; it CAN require the trail).
# Space-separated, relative to ROOT. Override a single commit with CHEATSHEET_RULE_OK=1.
CORE_RULE_FILES="diff/common.md"

is_index() { local b; b=$(basename "$1"); [ "$b" = "INDEX.md" ] || [ "$b" = "CHEATSHEET-INDEX.md" ]; }
relp() { realpath --relative-to="$ROOT" "$1" 2>/dev/null || echo "$1"; }
slug() { echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9 -]//g; s/ +/-/g'; }

# Emit broken-link lines for ONE file: "<tgt>\t<reason>". Empty if clean.
broken_links_in() {
  local f="$1" dir tgt path anchor res have
  dir=$(dirname "$f")
  grep -oE '\]\([^)]+\)' "$f" 2>/dev/null | sed -E 's/^\]\(//; s/\)$//' | while IFS= read -r tgt; do
    case "$tgt" in http://*|https://*|\#*|mailto:*) continue ;; esac
    path="${tgt%%#*}"; anchor="${tgt#*#}"; [ "$anchor" = "$tgt" ] && anchor=""
    case "$path" in *.md) ;; *) continue ;; esac
    case "$path" in
      "~"*) res="${path/#\~/$HOME}" ;;
      /*)   res="$path" ;;
      *)    res="$dir/$path" ;;
    esac
    if [ ! -e "$res" ]; then
      printf '%s\tmissing file\n' "$tgt"
    elif [ -n "$anchor" ]; then
      have=$(grep -E '^#{1,6} ' "$res" | sed -E 's/^#+ +//; s/ +#*$//' | while IFS= read -r h; do slug "$h"; done | grep -Fxq "$anchor" && echo ok)
      [ "$have" = ok ] || printf '%s\tmissing #anchor\n' "$tgt"
    fi
  done
}

# Emit broken backtick `path.md` refs for ONE file: "<ref>". Empty if clean.
# PRECISE by design: only flags refs that are unambiguously meant to be LOCAL
# cheatsheets — folder-qualified (career/..., oncall/..., etc.) or the abolished
# `cheatsheet-` prefix. Bare names with no folder (e.g. `SKILL.md`,
# `incident_report_guide.md`) are external source CITATIONS, not links — skipped
# to avoid false positives.
broken_backtick_refs_in() {
  local f="$1" ref
  grep -oE '`[A-Za-z0-9_*<>./-]+\.md`' "$f" 2>/dev/null | tr -d '`' | sort -u | while IFS= read -r ref; do
    # skip template/placeholder tokens used in docs (cheatsheet-X.md, foo-*.md,
    # <name>.md) — real cheatsheet basenames are lowercase-hyphen, never these.
    case "$ref" in
      *'*'*|*'<'*|*'>'*) continue ;;
      cheatsheet-*[A-Z]*) continue ;;
    esac
    case "$ref" in
      cheatsheet-*) ;;
      career/*|oncall/*|diff/*|comms/*|gdocs/*|system/*|agents/*|research/*|calendar/*|references/*|reliability/*|eval/*) ;;
      *) continue ;;
    esac
    [ -e "$ROOT/$ref" ] || printf '%s\n' "$ref"
  done
}

# --------------------------------------------------------------- --gate mode --
if [ "$1" = "--gate" ]; then
  shift
  files=("$@")
  if [ "${#files[@]}" -eq 0 ]; then
    mapfile -t files < <(cd "$ROOT" && sl status -n . 2>/dev/null | grep '\.md$' | sed "s#^#$ROOT/#")
  fi
  block=0
  for f in "${files[@]}"; do
    [ -f "$f" ] || continue
    case "$f" in *.md) ;; *) continue ;; esac
    is_index "$f" && continue
    if ! grep -qi "last updated:" "$f"; then
      echo "BLOCK: $(relp "$f") — no 'Last updated:' footer (add one; --stamp gives the line)" >&2
      block=1
    fi
    while IFS=$'\t' read -r tgt why; do
      [ -z "$tgt" ] && continue
      echo "BLOCK: $(relp "$f") — broken link $tgt ($why)" >&2
      block=1
    done < <(broken_links_in "$f")
    while IFS= read -r ref; do
      [ -z "$ref" ] && continue
      echo "BLOCK: $(relp "$f") — broken local ref \`$ref\` (folder-qualified/legacy, does not resolve)" >&2
      block=1
    done < <(broken_backtick_refs_in "$f")
    # Rule grounding & evidence gate (Contract C1/C2), on the NEW rule bullets this
    # change introduces (working vs sl-committed parent). GROUNDING runs on EVERY
    # cheatsheet (incl. brand-new files); EVIDENCE-LOG only on core files.
    # Override a single commit with CHEATSHEET_RULE_OK=1.
    rel=$(relp "$f")
    if [ -z "${CHEATSHEET_RULE_OK:-}" ]; then
      abs=$(realpath "$f" 2>/dev/null)
      parent=$(cd "$(dirname "$abs")" && sl cat -r . "$abs" 2>/dev/null)
      new_bullets=$(comm -13 <(printf '%s\n' "$parent" | grep -E '^- \*\*' | sort -u) <(grep -E '^- \*\*' "$f" | sort -u))
      if [ -n "$new_bullets" ]; then
        # (a) GROUNDING — all files: each new rule bullet cites a source token.
        CIT='D[0-9]{5,}|S[0-9]{5,}|T[0-9]{5,}|P[0-9]{5,}|[0-9]{4}-[0-9]{2}-[0-9]{2}|https?://|internalfb\.com|fburl|[A-Za-z0-9_./-]+\.(py|sh|md|cpp|cc|h|thrift|cinc|cconf|js|ts|java|rs):[0-9]+'
        ungrounded=0
        ungrounded_lines=""
        while IFS= read -r line; do
          [ -z "$line" ] && continue
          printf '%s' "$line" | grep -qE "$CIT" || ungrounded_lines="${ungrounded_lines}         ${line:0:90}"$'\n'
        done <<< "$new_bullets"
        if [ -n "$ungrounded_lines" ]; then
          # Trust gradient: the auto-create pipeline opts into strict via CS_STRICT=1
          # (set by cheatsheet-accept.sh) — there, grounding is a hard BLOCK. Every
          # other path (interactive, cron edits) gets a WARN: craft/style rules
          # legitimately have no incident source; don't force a fabricated cite.
          # ($AGENT is unreliable — it's "claude_code" even in interactive sessions.)
          if [ -n "${CS_STRICT:-}" ]; then
            echo "BLOCK: $rel — machine-authored new rule bullet(s) lack a citation (D#/S#/T#/P#/date/URL/file:line):" >&2
            printf '%s' "$ungrounded_lines" >&2
            echo "       Cite the source, or set CHEATSHEET_RULE_OK=1." >&2
            block=1
          else
            echo "WARN: $rel — new rule bullet(s) without a citation (ok for craft rules; cite if incident-derived):" >&2
            printf '%s' "$ungrounded_lines" >&2
          fi
        fi
        # (b) EVIDENCE-LOG — core files only: a new core rule ships with a learnings entry.
        case " $CORE_RULE_FILES " in
          *" $rel "*)
            has_log=0
            for g in "${files[@]}"; do
              case "$(relp "$g")" in *learnings*.md) has_log=1 ;; esac
            done
            if [ "$has_log" -eq 0 ]; then
              echo "BLOCK: $rel — new core rule bullet with no *learnings*.md entry in this commit." >&2
              echo "       Log the evidence in diff/diff-learnings-log.md (promote a rule only after >=3 dated occurrences), or CHEATSHEET_RULE_OK=1." >&2
              block=1
            fi
            ;;
        esac
      fi
    fi
    c=$(wc -l < "$f")
    [ "$c" -gt "$CAP" ] && echo "WARN: $(relp "$f") $c lines (> $CAP cap — debt, not blocking)" >&2
  done
  exit "$block"
fi

# ----------------------------------------------------------- --fix-index mode --
# Auto-heal the "Files" count column in CHEATSHEET-INDEX.md from the actual *.md
# count per category folder (excluding INDEX.md). Deterministic + reversible, so
# it lives in the auto-fix tier (cheatsheet-sweep.sh calls it). Only the count
# field is touched — the row's description text is preserved.
if [ "$1" = "--fix-index" ]; then
  idx="$ROOT/CHEATSHEET-INDEX.md"
  [ -f "$idx" ] || { echo "no index at $idx" >&2; exit 2; }
  ROOT="$ROOT" perl -i -pe '
    s{^(\| .*? \| `([a-z]+)/` \| )(\d+)( \|)}{
      my ($pre,$folder,$old,$post) = ($1,$2,$3,$4);
      my @f = grep { !m{/INDEX\.md$} } glob("$ENV{ROOT}/$folder/*.md");
      my $n = scalar @f;
      print STDERR "  fix-index: $folder/ $old -> $n\n" if $n != $old;
      "$pre$n$post";
    }e;
  ' "$idx"
  exit 0
fi

# ---------------------------------------------------- --audit-grounding mode --
# Read-only. Reports EXISTING rule bullets (`- **...`) tree-wide that lack a
# citation token. The --gate grounding check only catches NEW bullets; this
# surfaces the pre-grounding-rule backlog so it can be backfilled or demoted.
if [ "$1" = "--audit-grounding" ]; then
  CIT='D[0-9]{5,}|S[0-9]{5,}|T[0-9]{5,}|P[0-9]{5,}|[0-9]{4}-[0-9]{2}-[0-9]{2}|https?://|internalfb\.com|fburl|[A-Za-z0-9_./-]+\.(py|sh|md|cpp|cc|h|thrift|cinc|cconf|js|ts|java|rs):[0-9]+'
  tot=0; ung=0
  while IFS= read -r f; do
    is_index "$f" && continue
    fung=0; ftot=0
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      ftot=$((ftot+1)); tot=$((tot+1))
      printf '%s' "$line" | grep -qE "$CIT" || { fung=$((fung+1)); ung=$((ung+1)); }
    done < <(grep -E '^- \*\*' "$f")
    [ "$fung" -gt 0 ] && printf '  %3d/%-3d ungrounded  %s\n' "$fung" "$ftot" "$(relp "$f")"
  done < <(find "$ROOT" -name '*.md' | sort)
  pct=$(awk -v u="$ung" -v t="$tot" 'BEGIN{printf (t? "%.0f":"0"), (t? u*100/t:0)}')
  echo "# grounding audit: $ung / $tot rule bullets lack a citation token (${pct}%)"
  exit 0
fi

mapfile -t FILES < <(find "$ROOT" -name '*.md' | sort)
[ "${#FILES[@]}" -gt 0 ] || { echo "no .md under $ROOT" >&2; exit 2; }

# ----------------------------------------------------------------- --fix mode --
# Auto-apply ONLY unambiguous, reversible fixes: legacy `cheatsheet-X.md` refs
# whose un-prefixed basename resolves to exactly ONE `*/X.md` in the tree. Dead
# refs (no target) and folder-qualified misses are left for the draft/review
# tier — never guessed. This is what the periodic structural-sweep station runs.
if [ "$1" = "--fix" ]; then
  fixed=0; left=0
  for f in "${FILES[@]}"; do
    while IFS= read -r ref; do
      [ -z "$ref" ] && continue
      case "$ref" in cheatsheet-*) ;; *) echo "  SKIP (needs decision): $(relp "$f") -> \`$ref\`"; left=$((left+1)); continue ;; esac
      base="${ref#cheatsheet-}"
      mapfile -t hits < <(cd "$ROOT" && find . -name "$base" | sed 's#^\./##')
      if [ "${#hits[@]}" -eq 1 ]; then
        perl -i -pe "s#\Q$ref\E#${hits[0]}#g" "$f"
        echo "  FIXED: $(relp "$f")  \`$ref\` -> \`${hits[0]}\`"; fixed=$((fixed+1))
      else
        echo "  SKIP (no unique target, ${#hits[@]} matches): $(relp "$f") -> \`$ref\`"; left=$((left+1))
      fi
    done < <(broken_backtick_refs_in "$f")
  done
  echo "# --fix: $fixed applied, $left left for review"
  exit 0
fi

# --------------------------------------------------------------- --stamp mode --
if [ "$1" = "--stamp" ]; then
  for f in "${FILES[@]}"; do
    is_index "$f" && continue
    grep -qi "last updated:" "$f" && continue
    d=$(cd "$(dirname "$f")" && sl log -l 1 -T '{date|shortdate}' "$f" 2>/dev/null)
    [ -z "$d" ] && d="unknown"
    printf '%s\t_Last updated: %s. Maintainer: dennyzhang._\n' "$(relp "$f")" "$d"
  done
  exit 0
fi

# ------------------------------------------------------------- full audit -----
findings=0
echo "# Cheatsheet health-check — ${#FILES[@]} files under $ROOT"

echo ""; echo "## SIZE — over ${CAP}-line cap"
n=0
for f in "${FILES[@]}"; do
  c=$(wc -l < "$f")
  if [ "$c" -gt "$CAP" ]; then printf '  %5d  %s\n' "$c" "$(relp "$f")"; n=$((n+1)); findings=$((findings+1)); fi
done
[ "$n" = 0 ] && echo "  (none)"

echo ""; echo "## PROVENANCE — no 'Last updated' marker"
n=0
for f in "${FILES[@]}"; do
  is_index "$f" && continue
  if ! grep -qi "last updated:" "$f"; then echo "  $(relp "$f")"; n=$((n+1)); findings=$((findings+1)); fi
done
[ "$n" = 0 ] && echo "  (none)" || echo "  -> run with --stamp for ready-to-paste footers (real sl dates)"

echo ""; echo "## LINKS — broken relative .md links"
: > /tmp/.cs_links
for f in "${FILES[@]}"; do
  while IFS=$'\t' read -r tgt why; do
    [ -z "$tgt" ] && continue
    echo "  $(relp "$f")  ->  $tgt  ($why)" >> /tmp/.cs_links
  done < <(broken_links_in "$f")
done
sort -u /tmp/.cs_links; n=$(grep -c . /tmp/.cs_links 2>/dev/null); n=${n:-0}
[ "$n" = 0 ] && echo "  (none)"
findings=$((findings+n))

echo ""; echo "## REFS — broken backtick local .md refs (folder-qualified/legacy)"
: > /tmp/.cs_refs
for f in "${FILES[@]}"; do
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    echo "  $(relp "$f")  ->  \`$ref\`" >> /tmp/.cs_refs
  done < <(broken_backtick_refs_in "$f")
done
sort -u /tmp/.cs_refs; n=$(grep -c . /tmp/.cs_refs 2>/dev/null); n=${n:-0}
[ "$n" = 0 ] && echo "  (none)"
findings=$((findings+n))

echo ""; echo "## ORPHANS — content .md referenced by no other .md"
n=0
for f in "${FILES[@]}"; do
  is_index "$f" && continue
  b=$(basename "$f")
  refs=$(grep -rlF "$b" --include='*.md' "$ROOT" | grep -vxF "$f" | wc -l)
  if [ "$refs" -eq 0 ]; then echo "  $(relp "$f")"; n=$((n+1)); findings=$((findings+1)); fi
done
[ "$n" = 0 ] && echo "  (none)"

echo ""; echo "# $findings finding(s)"
[ "$findings" -gt 0 ] && exit 1 || exit 0
