#!/usr/bin/env bash
# rebase-diff.sh — atomic rebase of a Phabricator diff onto latest trunk, for
# BOTH fbsource and configerator, with a VERIFIED version bump. One command.
#
# WHY THIS EXISTS (2026-06-15, D107966514): a configerator rebase took 47 min because
# the WRONG path was used. `meta phabricator.diff rebase` (the remote Sandcastle rebase)
# is a NO-OP for a zero-delta configerator diff — it runs ~16 min and never mints a new
# version, so the requester still sees the stale version. The actual local flow is ~4 min:
#   fbclone (if no checkout, ~5s) -> jf get -> sl pull -> sl rebase -> conf build -> conf submit.
# This wrapper goes LOCAL-FIRST, auto-detects the repo, and FAILS LOUD if the Phab
# version does not advance (the only real definition of "rebased" — see common.md META-RULE).
#
# Usage: rebase-diff.sh D<number>
#   - fbsource  (repository FBS):  goto -> pull -> rebase -> jf submit -> verify
#   - configerator (repo CFHG):    [fbclone] -> jf get -> pull -> rebase -> conf build -> conf submit -> verify
#
# NEVER use `meta phabricator.diff rebase` for configerator — it cannot bump a zero-delta version.

set -uo pipefail

raw="${1:?usage: rebase-diff.sh D<number>}"
DNUM="D${raw#D}"   # normalize to D-prefixed

log(){ echo "[rebase-diff $(date +%H:%M:%S)] $*"; }
die(){ echo "[rebase-diff ERROR] $*" >&2; exit 1; }

# ── detect repo + record baseline version ──────────────────────────────────
desc=$(meta phabricator.diff describe --number="$DNUM" 2>&1) || die "describe failed for $DNUM"
repo=$(echo "$desc" | grep -E "^  repository:" | awk '{print $2}' | head -1)
base_ver=$(echo "$desc" | grep -E "^  latest_version_number:" | awk '{print $2}' | head -1)
[ -z "$repo" ] && die "could not detect repository for $DNUM"
log "diff=$DNUM repo=$repo baseline_version=$base_ver"

verify_bump(){
    sleep 6
    local nv
    nv=$(meta phabricator.diff describe --number="$DNUM" 2>&1 | grep -E "^  latest_version_number:" | awk '{print $2}' | head -1)
    if [ -n "$nv" ] && [ "$nv" != "$base_ver" ]; then
        log "SUCCESS — Phab version advanced ${base_ver} -> ${nv}"
        exit 0
    fi
    die "version did NOT advance (still ${base_ver}) — rebase NOT complete; investigate manually"
}

case "$repo" in
    CFHG)
        CFG="$HOME/configerator"
        if [ ! -d "$CFG/.hg" ] && [ ! -d "$CFG/.sl" ]; then
            log "no configerator checkout — fbclone (one-time, ~5s)"
            fbclone configerator "/data/users/$USER/configerator" >/dev/null 2>&1 || die "fbclone configerator failed"
        fi
        cd "$CFG" || die "cd $CFG failed"
        log "jf get $DNUM"; jf get "$DNUM" >/dev/null 2>&1 || die "jf get $DNUM failed"
        commit=$(sl --reason "rebase-diff: locate $DNUM" log -r "$DNUM" -T '{node|short}' 2>/dev/null)
        [ -z "$commit" ] && die "could not resolve $DNUM to a local commit"
        log "sl pull (latest trunk)"; sl --reason "rebase-diff: pull trunk for $DNUM" pull >/dev/null 2>&1 || die "sl pull failed"
        log "sl rebase $commit -> remote/master"
        sl --reason "rebase-diff: rebase $DNUM onto trunk" rebase -r "$commit" -d remote/master 2>&1 | tail -3
        newc=$(sl --reason "rebase-diff: find rebased $DNUM" log -r "$DNUM" -T '{node|short}' 2>/dev/null)
        [ -z "$newc" ] && die "lost track of $DNUM after rebase"
        sl --reason "rebase-diff: goto rebased $DNUM" goto "$newc" >/dev/null 2>&1 || die "goto rebased commit failed"
        log "conf build (regenerate materialized vs new trunk; may take a few min)"
        conf build 2>&1 | tail -4 || die "conf build failed"
        log "conf submit (mint new version; --verbatim carries acceptance)"
        conf submit --diff "$DNUM" --non-interactive --verbatim 2>&1 | tail -5   # diff-cheatsheet-ok
        verify_bump
        ;;
    FBS)
        cd "$HOME/fbsource" || die "cd fbsource failed"
        commit=$(sl --reason "rebase-diff: locate $DNUM" log -r "$DNUM" -T '{node|short}' 2>/dev/null)
        [ -z "$commit" ] && die "could not resolve $DNUM to a local commit"
        sl --reason "rebase-diff: goto $DNUM" goto "$commit" >/dev/null 2>&1 || die "goto $DNUM failed"
        log "sl pull (latest trunk)"; sl --reason "rebase-diff: pull trunk" pull >/dev/null 2>&1 || die "sl pull failed"
        log "sl rebase -> remote/master"
        sl --reason "rebase-diff: rebase $DNUM onto trunk" rebase -d remote/master 2>&1 | tail -3
        newc=$(sl --reason "rebase-diff: find rebased $DNUM" log -r "$DNUM" -T '{node|short}' 2>/dev/null)
        [ -z "$newc" ] && die "lost track of $DNUM after rebase"
        sl --reason "rebase-diff: goto rebased $DNUM" goto "$newc" >/dev/null 2>&1 || die "goto rebased commit failed"
        log "jf submit (mint new version)"
        jf submit --update-fields 2>&1 | tail -5   # diff-cheatsheet-ok
        verify_bump
        ;;
    *)
        die "unsupported repository '$repo' for $DNUM (handled: FBS, CFHG)"
        ;;
esac
