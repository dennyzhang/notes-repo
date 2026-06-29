#!/bin/bash
# Bootstrap script for the ot-team MyClaw instance.
#
# Post-init patcher: copies fbcode-versioned team-bot artifacts into
# ~/.myclaw-ot-bot/ so the instance boots with the latest reviewed policy.
# Idempotent — safe to re-run after every devserver reinstall or fbcode pull.
#
# Overwrite policy (re-run safe):
#   - CLAUDE.md: always overwritten (pure policy, fbcode = source of truth).
#   - team_bot_config.yaml:
#     - First run: installed from fbcode default.
#     - Re-runs: deep-merged with python + PyYAML so new keys from fbcode
#       (e.g., mention_keyword added in D102927735) are picked up
#       automatically; user-customized values (target_space_id, bot_id)
#       are preserved because local wins on leaf conflicts. Backup written
#       to *.pre-merge-<timestamp> before mutate so a bad merge can be
#       rolled back. Comments are NOT preserved on re-runs — the canonical
#       comments live in fbcode anyway, and the daemon reads values, not
#       prose. To force-reset to the fbcode default, delete the file
#       before re-running.
#
# Prerequisite: a human has run `myclaw init ot-team` interactively and
# bound the instance to an OT workstream GChat space (Phase-0 unblocker
# 0.2). This script refuses to run if ~/.myclaw-ot-bot/ is missing.
#
# Tracker: T266536788
# Plan:    https://docs.google.com/document/d/1MQM6zZjfO26VcaIEPmgxJYKSzB0_FaAsXfwpWYMTQlY/edit

set -euo pipefail

readonly MYCLAW_HOME="${HOME}/.myclaw-ot-bot"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

if [[ ! -d "${MYCLAW_HOME}" ]]; then
  cat >&2 <<EOF
[ot-team bootstrap] ${MYCLAW_HOME} does not exist.

Run the interactive init first — it opens a browser for OAuth and GChat
space binding:
  myclaw init ot-team

After it finishes, re-run this script to patch the instance with fbcode
artifacts.
EOF
  exit 1
fi

# Pre-check sibling artifacts before touching the instance home. install(1)
# partway through would leave the instance with one file stale and one fresh
# — worse than a clean refusal. This also catches the case where a user
# cherry-picks bootstrap.sh without the accompanying diffs landing.
missing=()
for artifact in CLAUDE.md team_bot_config.yaml; do
  if [[ ! -f "${SCRIPT_DIR}/${artifact}" ]]; then
    missing+=("${artifact}")
  fi
done
if [[ ${#missing[@]} -gt 0 ]]; then
  {
    echo "[ot-team bootstrap] missing sibling artifact(s) in ${SCRIPT_DIR}:"
    printf '  - %s\n' "${missing[@]}"
    echo
    echo "Pull fbcode to a revision where D102273812 (team_bot_config.yaml)"
    echo "and D102273961 (CLAUDE.md) have landed, then re-run."
  } >&2
  exit 2
fi

echo "[ot-team bootstrap] patching ${MYCLAW_HOME} from ${SCRIPT_DIR} ..."

# ---------------------------------------------------------------------------
# ensure_symlinks() — wire up versioned state files (2026-05-16)
# ---------------------------------------------------------------------------
# Reads ~/notes/users/dennyzhang/projects/mrs-ot-agent-context/state-symlinks.manifest
# and ensures every listed local path is a symlink into the notes repo. Lets us
# version cron-state / learnings / cron-prompt-backups under Sapling while keeping
# the local paths the daemon writes to. See RULES.md §"Where state files live".
#
# Lifecycle (per manifest row):
#   - Symlink already correct                                     → no-op
#   - Local file exists, notes target missing                     → mv local → notes, then symlink
#   - Notes target exists, local missing (fresh devserver)        → just create symlink
#   - Local + notes both exist as regular files (CONFLICT)        → notes wins; local backed up
#   - Neither exists, and target ends in .json                    → seed empty `{}` in notes, then symlink
# Idempotent. Non-fatal: failures log a warning, bootstrap continues.

ensure_symlinks() {
  local notes_root="${HOME}/notes"
  local manifest="${notes_root}/users/dennyzhang/projects/mrs-ot-agent-context/state-symlinks.manifest.txt"

  # Wait up to 30s for notes mount (eden cold-start race after reboot/reinstall).
  local waited=0
  while [[ ! -d "${notes_root}/users/dennyzhang/projects/mrs-ot-agent-context" ]]; do
    if [[ ${waited} -ge 30 ]]; then
      echo "[ot-team bootstrap] WARNING: notes mount not ready after 30s; skipping ensure_symlinks" >&2
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done

  if [[ ! -f "${manifest}" ]]; then
    echo "[ot-team bootstrap] no symlink manifest at ${manifest}; skipping ensure_symlinks"
    return 0
  fi

  local linked=0 migrated=0 conflicted=0 noop=0

  while IFS= read -r line; do
    # Skip blanks + comments
    [[ -z "${line// }" ]] && continue
    [[ "${line}" =~ ^[[:space:]]*# ]] && continue

    # Parse `<local_rel> -> <notes_rel>` (whitespace tolerant)
    if [[ ! "${line}" =~ ^[[:space:]]*([^[:space:]]+)[[:space:]]+-\>[[:space:]]+([^[:space:]]+)[[:space:]]*$ ]]; then
      echo "[ot-team bootstrap] WARNING: unparseable manifest row: ${line}" >&2
      continue
    fi
    local local_rel="${BASH_REMATCH[1]}"
    local notes_rel="${BASH_REMATCH[2]}"
    local local_abs="${MYCLAW_HOME}/${local_rel}"
    local notes_abs="${notes_root}/${notes_rel}"

    # Case 1: already a correct symlink — no-op
    if [[ -L "${local_abs}" ]] && [[ "$(readlink "${local_abs}")" == "${notes_abs}" ]]; then
      noop=$((noop + 1))
      continue
    fi

    # Case 4: CONFLICT — both local (regular file) AND notes target exist
    if [[ -e "${local_abs}" ]] && [[ ! -L "${local_abs}" ]] && [[ -e "${notes_abs}" ]]; then
      local backup="${local_abs}.bootstrap-conflict.$(date +%s)"
      mv "${local_abs}" "${backup}"
      echo "[ot-team bootstrap] CONFLICT on ${local_rel} — local backed up to ${backup}; notes wins" >&2
      conflicted=$((conflicted + 1))
    fi

    # Case 2: local exists, notes missing — migrate local → notes
    if [[ -e "${local_abs}" ]] && [[ ! -L "${local_abs}" ]] && [[ ! -e "${notes_abs}" ]]; then
      mkdir -p "$(dirname "${notes_abs}")"
      mv "${local_abs}" "${notes_abs}"
      echo "[ot-team bootstrap] migrated ${local_rel} → notes"
      migrated=$((migrated + 1))
    fi

    # Case 5: neither exists — seed JSON state files with empty object
    if [[ ! -e "${local_abs}" ]] && [[ ! -e "${notes_abs}" ]]; then
      mkdir -p "$(dirname "${notes_abs}")"
      if [[ "${notes_abs}" == *.json ]]; then
        echo '{}' > "${notes_abs}"
      elif [[ "${notes_abs}" == *.md ]]; then
        : > "${notes_abs}"
      else
        # Non-file target (probably a directory) — create empty dir
        mkdir -p "${notes_abs}"
      fi
    fi

    # Stale symlink / wrong target / leftover file pointing elsewhere — remove
    if [[ -L "${local_abs}" ]] || [[ -e "${local_abs}" ]]; then
      rm -rf "${local_abs}"
    fi

    # Create the symlink (parent dir must exist on the local side)
    mkdir -p "$(dirname "${local_abs}")"
    ln -sfn "${notes_abs}" "${local_abs}"
    linked=$((linked + 1))
    echo "[ot-team bootstrap] linked ${local_rel} → notes"

  done < "${manifest}"

  echo "[ot-team bootstrap] ensure_symlinks done: linked=${linked} migrated=${migrated} conflicted=${conflicted} noop=${noop}"
}

ensure_symlinks

# Pre-overwrite guard for CLAUDE.md: refuse if local has unsynced edits
# that fbcode doesn't carry. Without this, an operator who edited
# ~/.myclaw-ot-bot/CLAUDE.md and forgot to run sync-from-local.sh
# loses those edits silently when bootstrap re-runs (the install line
# below "always overwrite"). Symmetric guard to sync-from-local.sh's
# "fbcode is ahead" warning. Threshold: ≥3 local-only lines treated
# as real divergence (matches sync-from-local heuristic).
#
# Override: --force-bootstrap (NOT --force, which is sync-from-local's
# flag; using a distinct name avoids reflexive cross-script muscle
# memory).
if [[ -f "${MYCLAW_HOME}/CLAUDE.md" ]]; then
  local_only_lines=$(diff "${SCRIPT_DIR}/CLAUDE.md" "${MYCLAW_HOME}/CLAUDE.md" \
      | grep -c '^>' || true)
  if [[ "${local_only_lines}" -ge 3 ]]; then
    if [[ "${1:-}" != "--force-bootstrap" ]]; then
      cat >&2 <<EOF
[ot-team bootstrap] WARNING: local CLAUDE.md has ${local_only_lines}
unsynced lines that fbcode does not carry. Overwriting now would
silently discard them.

Recovery options:
  1. Push local edits to fbcode first (recommended):
     ${SCRIPT_DIR}/sync-from-local.sh
     cd ~/fbsource && sl commit + jf submit, then re-run bootstrap.

  2. Discard local edits and accept fbcode as canonical:
     $0 --force-bootstrap

Diff (fbcode vs local) preview:
EOF
      diff -u "${SCRIPT_DIR}/CLAUDE.md" "${MYCLAW_HOME}/CLAUDE.md" \
          | head -40 >&2 || true
      exit 5
    fi
    echo "[ot-team bootstrap] --force-bootstrap given, overwriting" >&2
    echo "  local CLAUDE.md (${local_only_lines} lines will be lost)." >&2
  fi
fi

# CLAUDE.md is pure policy — fbcode is source of truth, always overwrite.
install -m 0644 "${SCRIPT_DIR}/CLAUDE.md" "${MYCLAW_HOME}/CLAUDE.md"

# team_bot_config.yaml carries target_space_id + bot_id which are set
# per-deployment at runtime. First run: install the fbcode default. Re-runs:
# deep-merge fbcode + local with local-wins precedence, so new fbcode keys
# (e.g., mention_keyword from D102927735) are picked up automatically while
# user customizations are preserved. Backup written before mutate.
if [[ -f "${MYCLAW_HOME}/team_bot_config.yaml" ]]; then
  backup="${MYCLAW_HOME}/team_bot_config.yaml.pre-merge-$(date +%Y%m%d-%H%M%S)"
  cp -p "${MYCLAW_HOME}/team_bot_config.yaml" "${backup}"

  if python3 - \
      "${SCRIPT_DIR}/team_bot_config.yaml" \
      "${MYCLAW_HOME}/team_bot_config.yaml" \
      > "${MYCLAW_HOME}/team_bot_config.yaml.tmp" <<'PYEOF'
import sys

import yaml


def merge(a, b):
    """Deep-merge a (fbcode) and b (local); local wins on leaf conflicts."""
    if isinstance(a, dict) and isinstance(b, dict):
        result = dict(a)
        for key, value in b.items():
            result[key] = merge(result[key], value) if key in result else value
        return result
    return b


with open(sys.argv[1]) as f:
    fbcode = yaml.safe_load(f) or {}
with open(sys.argv[2]) as f:
    local = yaml.safe_load(f) or {}
# Guard: an empty / comments-only YAML deserializes to None. Without `or {}`,
# merge(fbcode, None) falls through the isinstance check and returns None,
# which safe_dump writes as the literal string "null" — silently destroying
# the config on a successful exit (Devmate finding on D102930544).
yaml.safe_dump(
    merge(fbcode, local),
    sys.stdout,
    default_flow_style=False,
    sort_keys=False,
)
PYEOF
  then
    mv "${MYCLAW_HOME}/team_bot_config.yaml.tmp" \
       "${MYCLAW_HOME}/team_bot_config.yaml"
    config_action="merged (backup at ${backup})"
  else
    rm -f "${MYCLAW_HOME}/team_bot_config.yaml.tmp"
    config_action="kept (python+PyYAML merge failed — try 'pip3 install --user pyyaml' and re-run; backup at ${backup}, original preserved)"
  fi
else
  install -m 0644 "${SCRIPT_DIR}/team_bot_config.yaml" "${MYCLAW_HOME}/team_bot_config.yaml"
  config_action="installed"
fi

# Re-assert every cron job's prompt + schedule from the fbcode-tracked
# manifest (cron-jobs/MANIFEST.json + cron-jobs/*.md). Belt-and-suspenders
# over the Manifold sqlite restore: even a stale backup recovers to the
# canonical state. Idempotent — no-op if every row already matches.
# Failure here is non-fatal for bootstrap; print a warning and continue
# so the operator still gets CLAUDE.md / yaml refreshes even if jobs
# UPSERT can't run (e.g., sqlite locked, db schema drift).
if [[ -x "${SCRIPT_DIR}/setup-cron-jobs.sh" ]]; then
  echo
  echo "[ot-team bootstrap] re-asserting cron jobs from manifest ..."
  if ! "${SCRIPT_DIR}/setup-cron-jobs.sh"; then
    echo "[ot-team bootstrap] WARNING: setup-cron-jobs.sh failed — " \
         "job rows may be stale. Re-run by hand once unblocked:" >&2
    echo "  ${SCRIPT_DIR}/setup-cron-jobs.sh" >&2
  fi
fi

echo "[ot-team bootstrap] done. Installed files:"
ls -l "${MYCLAW_HOME}/CLAUDE.md" "${MYCLAW_HOME}/team_bot_config.yaml"

if [[ "${config_action}" == "installed" ]]; then
  cat <<'EOF'

Next steps (first-run setup):

1. Edit ~/.myclaw-ot-bot/team_bot_config.yaml and set target_space_id to
   the OT workstream GChat space ID (run `gchat space list` to find it).
   team_bot.py refuses to run with the default TBD.

2. Restart the instance so the new policy takes effect:
     myclaw-ot-bot restart

3. Verify the instance is listening:
     myclaw-ot-bot status

Mode is reply_on_mention (Phase 2, controlled). The bot replies in-thread
only when a message in target_space_id contains the mention_keyword
(`!ot-bot`, case-insensitive) AND matches a lane declared under
`lanes:` in team_bot_config.yaml (the yaml is the authoritative list —
e.g., MAST job id, SEV id, runbook path, workplace post).
To pause: any space member can type `/mute` for a 60-min kill switch.
To revert to drafts-only: set `mode: shadow` in team_bot_config.yaml
and restart.
EOF
elif [[ "${config_action}" == merged* ]]; then
  cat <<EOF

Re-run complete. ${config_action}

team_bot_config.yaml deep-merged with the latest fbcode default — new
fields (e.g., mention_keyword) added, your target_space_id + bot_id
preserved. Restart to pick up changes:
  myclaw-ot-bot restart

To force-reset to the fbcode default, delete the local first:
  rm ~/.myclaw-ot-bot/team_bot_config.yaml && "${SCRIPT_DIR}/bootstrap.sh"
EOF
else
  cat <<EOF

Re-run complete. ${config_action}

If new fbcode fields needed to be merged, fix the python+yaml issue and
re-run; otherwise edit ~/.myclaw-ot-bot/team_bot_config.yaml directly.
EOF
fi
