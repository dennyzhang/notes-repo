#!/usr/bin/env bash
# ask-gate.sh — deterministic ask/act gate for MyClaw (mechanism, not markdown).
#
# Given a TYPED action, prints "<verdict>|<reason>" where verdict is allow|ask,
# computed in CODE from gate-rules.json. The model only fills the fields; it does
# not get to "decide" whether to comply — the daemon enforces this verdict.
#
# This is Layer 2 of the design in README.md. It deliberately has NO `set -e`:
# a grep that finds nothing must not kill the gate (that bug already bit the cron
# fleet). Notes-repo legal: .sh + .json, no .py.
#
# Usage:
#   ask-gate.sh --kind Edit   --target "scripts/foo.sh"                      # -> allow
#   ask-gate.sh --kind Bash   --target "rm -rf /home/x"                      # -> ask (hard-floor)
#   ask-gate.sh --kind send   --target "tuowang" --external                  # -> ask
#   ask-gate.sh --kind Edit   --target "x.py" --reversible 0 --confident 0   # -> ask
#   ask-gate.sh --record allow --kind send --target "tuowang" --external     # store a precedent
#   ask-gate.sh --selftest
set -uo pipefail
# Resolve through symlinks: the daemon/hooks call this via the stable path
# $HOME/work/claude/state/ask-gate.sh (a symlink). Plain `dirname "$0"` would
# then resolve to the state dir, where gate-rules.json does NOT exist, so the
# catastrophic hard-floor would silently not load and rm -rf / force-push / land
# would fail OPEN to "allow". readlink -f follows the symlink to the notes dir
# where the rules + precedents actually live.
SELF="$(readlink -f "$0" 2>/dev/null || echo "$0")"
DIR="$(cd "$(dirname "$SELF")" && pwd)"
RULES="$DIR/gate-rules.json"
PRECEDENTS="${ASK_GATE_PRECEDENTS:-$DIR/precedents.jsonl}"

kind=""; target=""; external=0; reversible=1; blast="local"; confident=1
RECORD=""; SELFTEST=0
while [ $# -gt 0 ]; do case "$1" in
  --kind)       kind="$2";       shift 2;;
  --target)     target="$2";     shift 2;;
  --external)   external=1;      shift;;
  --reversible) reversible="$2"; shift 2;;   # 0|1
  --blast)      blast="$2";      shift 2;;   # none|local|shared|prod
  --confident)  confident="$2";  shift 2;;   # 0|1
  --record)     RECORD="$2";     shift 2;;   # allow|ask -> append precedent, then exit
  --selftest)   SELFTEST=1;      shift;;
  *) shift;;
esac; done

# Normalize a target to a CLASS (strip ids/hashes) so precedents match a class, not one instance.
_cls() { local t; t="$(printf '%s' "$target" | sed -E 's/[0-9]{4,}/#/g; s/[0-9a-f]{8,}/#/g')"
         printf '%s|%s|%s|%s' "$kind" "$t" "$blast" "$external"; }
_precedent_allows() { [ -f "$PRECEDENTS" ] && grep -Fxq "$(_cls) allow" "$PRECEDENTS"; }
record() { mkdir -p "$(dirname "$PRECEDENTS")"; printf '%s %s\n' "$(_cls)" "$1" >> "$PRECEDENTS"; }

decide() {
  # 1. hard floor (catastrophic) — always ask; Layer 1 should make these impossible
  if [ -r "$RULES" ]; then
    local pat why
    while IFS=$'\t' read -r pat why; do
      [ -n "$pat" ] && printf '%s' "$target" | grep -Eiq -e "$pat" && { echo "ask|hard-floor: $why"; return; }
    done < <(jq -r '.catastrophic_hard_floor[] | "\(.pattern)\t\(.why)"' "$RULES" 2>/dev/null)
  fi
  [ "$blast" = "prod" ] && { echo "ask|hard-floor: prod blast radius"; return; }
  # 2. precedent — approved this class before
  _precedent_allows && { echo "allow|precedent: approved before"; return; }
  # 3. external send to a human — gate unless precedent
  [ "$external" = "1" ] && { echo "ask|external send, no precedent - draft-then-show"; return; }
  # 4. reversible + low blast — the safe ~99%
  if [ "$reversible" = "1" ] && { [ "$blast" = "none" ] || [ "$blast" = "local" ]; }; then
    echo "allow|reversible, low blast"; return; fi
  # 5. irreversible — allow only if confident (Anthony's point: raises the bar, isn't itself the trigger)
  if [ "$reversible" = "0" ]; then
    [ "$confident" = "1" ] && echo "allow|irreversible+confident" || echo "ask|irreversible+unsure"; return; fi
  # 6. default
  [ "$confident" = "1" ] && echo "allow|default" || echo "ask|default"
}

if [ "$SELFTEST" = "1" ]; then
  PRECEDENTS="$(mktemp)"; pass=0; total=0
  check() { total=$((total+1)); local got="${out%%|*}" flag=XX
           [ "$got" = "$1" ] && { pass=$((pass+1)); flag=OK; }
           printf '  [%s] %-10s %-25s -> %-5s (%s)\n' "$flag" "$kind" "$target" "$got" "${out#*|}"; }
  kind=Edit  target="scripts/foo.sh"          external=0 reversible=1 blast=local  confident=1; out="$(decide)"; check allow
  kind=Bash  target="rm -rf /home/x"          external=0 reversible=1 blast=local  confident=1; out="$(decide)"; check ask
  kind=send  target="tuowang"                 external=1 reversible=1 blast=local  confident=1; out="$(decide)"; check ask
  kind=Bash  target="sl amend"                external=0 reversible=1 blast=local  confident=1; out="$(decide)"; check allow
  kind=Bash  target="git push --force origin" external=0 reversible=1 blast=shared confident=1; out="$(decide)"; check ask
  kind=Bash  target="deploy to prod"          external=0 reversible=1 blast=prod   confident=1; out="$(decide)"; check ask
  kind=Edit  target="x.cinc"                  external=0 reversible=0 blast=local  confident=1; out="$(decide)"; check allow
  kind=Edit  target="x.cinc"                  external=0 reversible=0 blast=local  confident=0; out="$(decide)"; check ask
  kind=send  target="tuowang" external=1 reversible=1 blast=local confident=1; record allow; out="$(decide)"; check allow
  printf '\n%s/%s pass\n' "$pass" "$total"; [ "$pass" = "$total" ]; exit
fi

if [ -n "$RECORD" ]; then record "$RECORD"; echo "recorded: $(_cls) $RECORD"; exit; fi
decide
