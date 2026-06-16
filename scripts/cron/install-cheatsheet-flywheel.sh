#!/usr/bin/env bash
# install-cheatsheet-flywheel.sh — idempotent (re)install of the cheatsheet
# flywheel's LOCAL activation after a devserver reinstall.
#
# The scripts/cheatsheets live in the notes repo and survive reinstall; this
# re-wires only the bits that get WIPED: the user crontab entries (sweep +
# harvest) and the sapling pretxncommit commit-gate. Safe to run repeatedly —
# every step checks-before-writing.
#
# Run after a reinstall (or any time, to self-heal):
#   bash ~/notes/users/dennyzhang/scripts/cron/install-cheatsheet-flywheel.sh
set -uo pipefail

add_cron() {  # $1 = unique marker, $2 = full crontab line
  # Marker MUST be specific enough to not substring-match another entry. Both the
  # sweep and harvest lines reference the shared `logs/cheatsheet-harvest/` path,
  # so a bare "cheatsheet-harvest" marker false-positives against the sweep line's
  # log path and silently skips adding the harvest cron. Always match the invoked
  # script filename (`*.sh`), which appears once and only in its own line.
  if crontab -l 2>/dev/null | grep -qF "$1"; then echo "  cron ok:    $1"; return; fi
  ( crontab -l 2>/dev/null; echo "$2" ) | crontab -
  echo "  cron added: $1"
}

add_cron "cheatsheet-sweep.sh" \
  "30 7 * * * \$HOME/notes/users/dennyzhang/scripts/cron/cheatsheet-sweep.sh >> \$HOME/logs/cheatsheet-harvest/sweep.log 2>&1  # cheatsheet structural sweep daily"
add_cron "cheatsheet-harvest.sh" \
  "0 8 * * 1 \$HOME/notes/users/dennyzhang/scripts/cron/cheatsheet-harvest.sh >> \$HOME/logs/cheatsheet-harvest/cron.log 2>&1  # cheatsheet-harvest weekly"
add_cron "cheatsheet-dedup-sweep.sh" \
  "30 8 * * 1 \$HOME/notes/users/dennyzhang/scripts/lint/cheatsheet-dedup-sweep.sh >> \$HOME/logs/cheatsheet-harvest/dedup.log 2>&1  # cheatsheet dedup/contradiction sweep weekly (LLM)"

# Sapling pretxncommit commit-gate (idempotent).
CONF="$HOME/.config/sapling/sapling.conf"
mkdir -p "$(dirname "$CONF")"; touch "$CONF"
HOOK="pretxncommit.cheatsheet-lint = bash ~/notes/users/dennyzhang/scripts/hooks/cheatsheet-lint-hook.sh"
if grep -q "cheatsheet-lint" "$CONF"; then
  echo "  hook ok:    pretxncommit.cheatsheet-lint"
elif grep -q "^\[hooks\]" "$CONF"; then
  awk -v l="$HOOK" '/^\[hooks\]/{print; print l; next} {print}' "$CONF" > "$CONF.tmp" && mv "$CONF.tmp" "$CONF"
  echo "  hook added: pretxncommit.cheatsheet-lint (existing [hooks])"
else
  printf '\n[hooks]\n%s\n' "$HOOK" >> "$CONF"
  echo "  hook added: pretxncommit.cheatsheet-lint (new [hooks])"
fi

mkdir -p "$HOME/logs/cheatsheet-harvest"
echo "cheatsheet-flywheel: local activation installed/verified"
