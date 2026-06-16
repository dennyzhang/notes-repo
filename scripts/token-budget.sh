#!/bin/bash
# Claude Code Token Budget Dashboard
# Measures token count of all files loaded at session startup.
# Run: bash scripts/token-budget.sh          # full dashboard
# Run: bash scripts/token-budget.sh --check  # quiet mode — warnings only, for /my-save
# Run: bash scripts/token-budget.sh --doctor # comprehensive overhead audit (cherry-picked from /claude-reset)
#
# Uses ~4 chars/token approximation (consistent with Task 1.3 findings).

set -e

CLAUDE_DIR="${HOME}/work/claude"
CHECK_MODE=false
if [[ "${1:-}" == "--check" ]]; then
    CHECK_MODE=true
fi

TOTAL_TOKENS=0
DIVIDER="────────────────────────────────────────────────────────"
WARNINGS=""

# Color codes
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

# Thresholds
TOKEN_WARN=60000   # 1M context model — generous budget
TOKEN_CRIT=100000
CONTEXT_BUDGET=40960  # 40KB in bytes — 1M context model has plenty of room
HOOK_WARN=6           # external .sh hook scripts — each costs ~200ms

count_tokens() {
    local file="$1"
    if [ -f "$file" ]; then
        local chars=$(wc -c < "$file")
        echo $(( chars / 4 ))
    else
        echo 0
    fi
}

print_file_row() {
    local label="$1"
    local file="$2"
    local tokens=$(count_tokens "$file")
    if [ "$tokens" -gt 0 ]; then
        printf "  %-45s %6d tokens\n" "$label" "$tokens"
        TOTAL_TOKENS=$((TOTAL_TOKENS + tokens))
        CATEGORY_TOKENS=$((CATEGORY_TOKENS + tokens))
    fi
}

echo -e "${BOLD}Claude Code Token Budget Dashboard${NC}"
echo "$DIVIDER"
echo ""

# === Always Loaded (repo root .md files + .claude.json) ===
CATEGORY_TOKENS=0
echo -e "${BOLD}ALWAYS LOADED${NC} (every session)"

# CLAUDE.md is always loaded
print_file_row "CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"

# Check if PROTOCOLS.md is at root (should be moved to config/)
if [ -f "$CLAUDE_DIR/PROTOCOLS.md" ]; then
    print_file_row "PROTOCOLS.md [WARNING: at root!]" "$CLAUDE_DIR/PROTOCOLS.md"
fi

# Other root .md files that Claude Code auto-loads
for f in "$CLAUDE_DIR"/ALERTS.md "$CLAUDE_DIR"/FOLLOWUPS.md; do
    if [ -f "$f" ]; then
        print_file_row "$(basename "$f")" "$f"
    fi
done

# .claude.json (session state)
if [ -f "$HOME/.claude.json" ]; then
    print_file_row ".claude.json (session state)" "$HOME/.claude.json"
fi

ALWAYS_TOKENS=$CATEGORY_TOKENS
printf "  ${BOLD}%-45s %6d tokens${NC}\n" "Subtotal: Always Loaded" "$ALWAYS_TOKENS"
echo ""

# === Startup Context (from CLAUDE.md startup steps) ===
CATEGORY_TOKENS=0
echo -e "${BOLD}STARTUP CONTEXT${NC} (loaded per CLAUDE.md steps)"

for f in "$CLAUDE_DIR/context/STATE.md" "$CLAUDE_DIR/context/STRATEGY.md" "$CLAUDE_DIR/context/meetings/MEETING-DIGEST.md"; do
    if [ -f "$f" ]; then
        print_file_row "$(echo "$f" | sed "s|$CLAUDE_DIR/||")" "$f"
    fi
done

STARTUP_TOKENS=$CATEGORY_TOKENS
printf "  ${BOLD}%-45s %6d tokens${NC}\n" "Subtotal: Startup Context" "$STARTUP_TOKENS"
echo ""

# === Agent Files ===
CATEGORY_TOKENS=0
echo -e "${BOLD}AGENT FILES${NC} (loaded when agents spawn)"

for f in "$CLAUDE_DIR"/agents/*.md; do
    if [ -f "$f" ]; then
        print_file_row "agents/$(basename "$f")" "$f"
    fi
done

AGENT_TOKENS=$CATEGORY_TOKENS
printf "  ${BOLD}%-45s %6d tokens${NC}\n" "Subtotal: Agent Files" "$AGENT_TOKENS"
echo ""

# === Command Files ===
CATEGORY_TOKENS=0
echo -e "${BOLD}COMMAND FILES${NC} (loaded on /command invoke)"

CMD_COUNT=0
for f in "$CLAUDE_DIR"/.claude/commands/*.md "$HOME"/.claude/commands/*.md; do
    if [ -f "$f" ]; then
        tokens=$(count_tokens "$f")
        CATEGORY_TOKENS=$((CATEGORY_TOKENS + tokens))
        TOTAL_TOKENS=$((TOTAL_TOKENS + tokens))
        CMD_COUNT=$((CMD_COUNT + 1))
    fi
done

COMMAND_TOKENS=$CATEGORY_TOKENS
printf "  %-45s %6d tokens (%d files)\n" "All command files" "$COMMAND_TOKENS" "$CMD_COUNT"
echo ""

# === Hook Scripts ===
CATEGORY_TOKENS=0
echo -e "${BOLD}HOOK SCRIPTS${NC} (not injected as tokens, but affect latency)"

HOOK_COUNT=0
for f in "$CLAUDE_DIR"/config/hooks/*.sh; do
    if [ -f "$f" ]; then
        tokens=$(count_tokens "$f")
        CATEGORY_TOKENS=$((CATEGORY_TOKENS + tokens))
        HOOK_COUNT=$((HOOK_COUNT + 1))
    fi
done

HOOK_TOKENS=$CATEGORY_TOKENS
# Don't add to TOTAL_TOKENS since hooks aren't injected as prompt tokens
TOTAL_TOKENS=$((TOTAL_TOKENS - CATEGORY_TOKENS))
printf "  %-45s %6d tokens (%d files) [not counted in total]\n" "All hook scripts" "$HOOK_TOKENS" "$HOOK_COUNT"
echo ""

# === On-Demand Context ===
CATEGORY_TOKENS=0
echo -e "${BOLD}ON-DEMAND CONTEXT${NC} (loaded when relevant)"

for f in "$CLAUDE_DIR"/cheatsheets/*.md; do
    if [ -f "$f" ]; then
        tokens=$(count_tokens "$f")
        CATEGORY_TOKENS=$((CATEGORY_TOKENS + tokens))
    fi
done
CHEATSHEET_COUNT=$(ls "$CLAUDE_DIR"/cheatsheets/*.md 2>/dev/null | wc -l)

for f in "$CLAUDE_DIR"/context/myself/PREFS.md "$CLAUDE_DIR"/context/STRATEGY-REFERENCE.md "$CLAUDE_DIR"/context/myself/GOALS-REFERENCE.md; do
    if [ -f "$f" ]; then
        tokens=$(count_tokens "$f")
        CATEGORY_TOKENS=$((CATEGORY_TOKENS + tokens))
    fi
done

ONDEMAND_TOKENS=$CATEGORY_TOKENS
# Don't add to session total since these are on-demand
TOTAL_TOKENS=$((TOTAL_TOKENS - CATEGORY_TOKENS))
printf "  %-45s %6d tokens (%d cheatsheets + context files) [not counted in total]\n" "All on-demand files" "$ONDEMAND_TOKENS" "$CHEATSHEET_COUNT"
echo ""

# === Plugin Token Overhead ===
CATEGORY_TOKENS=0
echo -e "${BOLD}PLUGIN SKILLS${NC} (loaded on trigger)"

SKILL_COUNT=0
for f in $(find "$HOME/.claude/plugins/cache" -name "SKILL.md" 2>/dev/null); do
    tokens=$(count_tokens "$f")
    CATEGORY_TOKENS=$((CATEGORY_TOKENS + tokens))
    SKILL_COUNT=$((SKILL_COUNT + 1))
done

PLUGIN_TOKENS=$CATEGORY_TOKENS
TOTAL_TOKENS=$((TOTAL_TOKENS - CATEGORY_TOKENS))
printf "  %-45s %6d tokens (%d skills) [not counted in total]\n" "All plugin skills" "$PLUGIN_TOKENS" "$SKILL_COUNT"
echo ""

# === Session Load Total ===
SESSION_LOAD=$((ALWAYS_TOKENS + STARTUP_TOKENS))
echo "$DIVIDER"
printf "${BOLD}SESSION LOAD (before first prompt):  %6d tokens${NC}\n" "$SESSION_LOAD"
printf "  Always loaded:                     %6d tokens\n" "$ALWAYS_TOKENS"
printf "  Startup context:                   %6d tokens\n" "$STARTUP_TOKENS"
echo ""

# === Plugin Summary ===
echo -e "${BOLD}ENABLED PLUGINS${NC}"
PLUGIN_LIST=$(cat "$HOME/.claude/settings.json" 2>/dev/null | jq -r '.enabledPlugins // {} | keys[]' 2>/dev/null)
PLUGIN_COUNT=$(echo "$PLUGIN_LIST" | wc -l)
echo "  $PLUGIN_COUNT plugins enabled:"
echo "$PLUGIN_LIST" | while read p; do
    case "$p" in
        meta@*|meta_codesearch@*|meta_knowledge@*) echo "    $p  [essential]" ;;
        meta-statusline-pro@*) echo "    $p  [UI]" ;;
        code_provenance@*|trajectory@*) echo "    $p  [telemetry]" ;;
        llm-rules@*) echo "    $p  [rules]" ;;
        *) echo "    $p" ;;
    esac
done
echo ""

# === Health Check ===
echo "$DIVIDER"
if [ "$SESSION_LOAD" -ge "$TOKEN_CRIT" ]; then
    echo -e "${RED}${BOLD}STATUS: CRITICAL${NC} — Session load exceeds ${TOKEN_CRIT} tokens"
    echo "  Action: Review always-loaded files for trimming opportunities"
    WARNINGS="${WARNINGS}TOKEN_CRITICAL:${SESSION_LOAD};"
elif [ "$SESSION_LOAD" -ge "$TOKEN_WARN" ]; then
    echo -e "${YELLOW}${BOLD}STATUS: WARNING${NC} — Session load exceeds ${TOKEN_WARN} tokens"
    echo "  Action: Monitor for growth, consider trimming verbose files"
    WARNINGS="${WARNINGS}TOKEN_WARN:${SESSION_LOAD};"
else
    echo -e "${GREEN}${BOLD}STATUS: HEALTHY${NC} — Session load is under ${TOKEN_WARN} tokens"
fi

# === Quick Wins ===
echo ""
echo -e "${BOLD}QUICK WINS${NC}"
if [ -f "$CLAUDE_DIR/PROTOCOLS.md" ]; then
    tokens=$(count_tokens "$CLAUDE_DIR/PROTOCOLS.md")
    echo "  - Move PROTOCOLS.md to config/ (save ~${tokens} tokens)"
fi

# Check for large always-loaded files
for f in "$CLAUDE_DIR"/*.md; do
    if [ -f "$f" ]; then
        tokens=$(count_tokens "$f")
        if [ "$tokens" -gt 3000 ] && [ "$(basename "$f")" != "CLAUDE.md" ]; then
            echo "  - $(basename "$f") is ${tokens} tokens — consider moving to config/"
        fi
    fi
done

echo ""
echo "Run this script periodically to track token budget changes."

# === --doctor mode: comprehensive overhead audit ===
# Cherry-picked from /claude-reset concept — finds dead weight, bloated files, stale configs.
DOCTOR_MODE=false
if [[ "${1:-}" == "--doctor" ]]; then
    DOCTOR_MODE=true
fi

if $DOCTOR_MODE; then
    echo ""
    echo "$DIVIDER"
    echo -e "${BOLD}TOKEN DOCTOR — Comprehensive Overhead Audit${NC}"
    echo ""
    DOCTOR_SAVINGS=0

    # 1. Auto-loaded root .md files — per-file breakdown
    echo -e "${BOLD}Auto-loaded files (root *.md)${NC}"
    for f in "$CLAUDE_DIR"/*.md; do
        if [ -f "$f" ]; then
            sz=$(wc -c < "$f")
            tokens=$((sz / 4))
            lines=$(wc -l < "$f")
            name=$(basename "$f")
            flag=""
            if [ "$tokens" -gt 4000 ] && [ "$name" != "CLAUDE.md" ]; then
                flag=" ${YELLOW}← LARGE${NC}"
            fi
            printf "  %-30s %6d tokens  (%3d lines)%b\n" "$name" "$tokens" "$lines" "$flag"
        fi
    done
    echo ""

    # 2. FOLLOWUPS.md dead weight — count Dropped section
    if [ -f "$CLAUDE_DIR/FOLLOWUPS.md" ]; then
        total_lines=$(wc -l < "$CLAUDE_DIR/FOLLOWUPS.md")
        dropped_start=$(grep -n "^## Dropped" "$CLAUDE_DIR/FOLLOWUPS.md" | head -1 | cut -d: -f1)
        if [ -n "$dropped_start" ]; then
            dropped_lines=$((total_lines - dropped_start))
            # Also count "Follow-up Additions" noise blocks
            noise_lines=$(grep -c "^# Follow-up Additions" "$CLAUDE_DIR/FOLLOWUPS.md" 2>/dev/null || echo 0)
            noise_bytes=$(grep -A5 "^# Follow-up Additions" "$CLAUDE_DIR/FOLLOWUPS.md" 2>/dev/null | wc -c)
            dropped_bytes=$(tail -n +"$dropped_start" "$CLAUDE_DIR/FOLLOWUPS.md" | wc -c)
            dead_tokens=$(( (dropped_bytes + noise_bytes) / 4 ))
            echo -e "  ${YELLOW}⚠ FOLLOWUPS.md dead weight: ~${dead_tokens} tokens${NC}"
            echo "    Dropped section: ${dropped_lines} lines (history, not actionable)"
            echo "    Noise blocks: ${noise_lines} 'Follow-up Additions' audit logs"
            echo -e "    ${BOLD}Fix: Move ## Dropped to backup/, delete noise blocks${NC}"
            DOCTOR_SAVINGS=$((DOCTOR_SAVINGS + dead_tokens))
        fi
    fi

    # 3. Settings.json overhead
    if [ -f "$HOME/.claude/settings.json" ]; then
        settings_tokens=$(count_tokens "$HOME/.claude/settings.json")
        printf "  %-30s %6d tokens\n" "settings.json" "$settings_tokens"
    fi
    echo ""

    # 4. Command files — find largest
    echo -e "${BOLD}Command files (loaded on invoke)${NC}"
    CMD_TOTAL=0
    LARGE_CMDS=""
    for f in "$CLAUDE_DIR"/.claude/commands/*.md "$HOME"/.claude/commands/*.md; do
        if [ -f "$f" ]; then
            tokens=$(count_tokens "$f")
            CMD_TOTAL=$((CMD_TOTAL + tokens))
            if [ "$tokens" -gt 2000 ]; then
                LARGE_CMDS="${LARGE_CMDS}  $(basename "$f"): ${tokens} tokens\n"
            fi
        fi
    done
    cmd_count=$(ls "$CLAUDE_DIR"/.claude/commands/*.md "$HOME"/.claude/commands/*.md 2>/dev/null | wc -l)
    printf "  %-30s %6d tokens  (%d files)\n" "Total commands" "$CMD_TOTAL" "$cmd_count"
    if [ -n "$LARGE_CMDS" ]; then
        echo -e "  ${YELLOW}Large commands (>2000 tokens):${NC}"
        echo -e "$LARGE_CMDS"
    fi
    echo ""

    # 5. Memory files
    echo -e "${BOLD}Memory files${NC}"
    MEM_TOTAL=0
    for memdir in "$HOME"/.claude/projects/*/memory/; do
        if [ -d "$memdir" ]; then
            for f in "$memdir"*.md; do
                if [ -f "$f" ]; then
                    tokens=$(count_tokens "$f")
                    MEM_TOTAL=$((MEM_TOTAL + tokens))
                    if [ "$tokens" -gt 500 ]; then
                        printf "  %-50s %6d tokens\n" "$(echo "$f" | sed "s|$HOME/||")" "$tokens"
                    fi
                fi
            done
        fi
    done
    if [ "$MEM_TOTAL" -eq 0 ]; then
        echo "  (none found)"
    fi
    echo ""

    # 6. Stale commands — not invoked recently (heuristic: check file age)
    echo -e "${BOLD}Stale commands (modified >30 days ago)${NC}"
    STALE_CMD_COUNT=0
    for f in "$CLAUDE_DIR"/.claude/commands/*.md; do
        if [ -f "$f" ]; then
            age_days=$(( ($(date +%s) - $(stat -c %Y "$f" 2>/dev/null || echo 0)) / 86400 ))
            if [ "$age_days" -gt 30 ]; then
                tokens=$(count_tokens "$f")
                printf "  %-30s %6d tokens  (%d days old)\n" "$(basename "$f")" "$tokens" "$age_days"
                STALE_CMD_COUNT=$((STALE_CMD_COUNT + 1))
            fi
        fi
    done
    if [ "$STALE_CMD_COUNT" -eq 0 ]; then
        echo "  (none — all commands recently modified)"
    fi
    echo ""

    # 7. Summary
    echo "$DIVIDER"
    if [ "$DOCTOR_SAVINGS" -gt 0 ]; then
        echo -e "${YELLOW}${BOLD}RECOVERABLE: ~${DOCTOR_SAVINGS} tokens of dead weight${NC}"
        echo "  Run the fixes above to reclaim context budget."
    else
        echo -e "${GREEN}${BOLD}CLEAN — no significant dead weight found${NC}"
    fi
    echo ""
    exit 0
fi

# === --check mode: self-tuning checks for /my-save ===
# Runs additional checks and outputs only warnings (no dashboard).
if $CHECK_MODE; then
    echo ""
    echo "$DIVIDER"
    echo -e "${BOLD}SELF-TUNING CHECKS${NC}"
    echo ""

    # Check 1: Context budget (startup files total size)
    CONTEXT_TOTAL=0
    for f in "$CLAUDE_DIR/context/STATE.md" "$CLAUDE_DIR/context/STRATEGY.md" "$CLAUDE_DIR/context/meetings/MEETING-DIGEST.md"; do
        if [ -f "$f" ]; then
            CONTEXT_TOTAL=$((CONTEXT_TOTAL + $(wc -c < "$f")))
        fi
    done
    if [ "$CONTEXT_TOTAL" -gt "$CONTEXT_BUDGET" ]; then
        echo -e "  ${YELLOW}⚠ Context files: ${CONTEXT_TOTAL} bytes (limit: ${CONTEXT_BUDGET})${NC}"
        # Find the largest file
        LARGEST=""
        LARGEST_SIZE=0
        for f in "$CLAUDE_DIR/context/STATE.md" "$CLAUDE_DIR/context/STRATEGY.md" "$CLAUDE_DIR/context/meetings/MEETING-DIGEST.md"; do
            if [ -f "$f" ]; then
                sz=$(wc -c < "$f")
                if [ "$sz" -gt "$LARGEST_SIZE" ]; then
                    LARGEST_SIZE=$sz
                    LARGEST=$(basename "$f")
                fi
            fi
        done
        echo "    Largest: $LARGEST (${LARGEST_SIZE} bytes) — consider splitting"
        WARNINGS="${WARNINGS}CONTEXT_OVER:${CONTEXT_TOTAL};"
    else
        echo -e "  ${GREEN}✓ Context files: ${CONTEXT_TOTAL} bytes (limit: ${CONTEXT_BUDGET})${NC}"
    fi

    # Check 2: External hook count (proxy for hook latency)
    SETTINGS_FILE="$CLAUDE_DIR/.claude/settings.json"
    EXTERNAL_HOOKS=0
    if [ -f "$SETTINGS_FILE" ]; then
        EXTERNAL_HOOKS=$(grep -c '\.sh"' "$SETTINGS_FILE" 2>/dev/null || true)
        EXTERNAL_HOOKS=${EXTERNAL_HOOKS:-0}
    fi
    if [ "$EXTERNAL_HOOKS" -gt "$HOOK_WARN" ]; then
        echo -e "  ${YELLOW}⚠ External hooks: ${EXTERNAL_HOOKS} (each costs ~200ms — consider consolidating)${NC}"
        WARNINGS="${WARNINGS}HOOKS_HIGH:${EXTERNAL_HOOKS};"
    else
        echo -e "  ${GREEN}✓ External hooks: ${EXTERNAL_HOOKS} (under ${HOOK_WARN})${NC}"
    fi

    # Check 3: Stale hook references (registered but file missing)
    if [ -f "$SETTINGS_FILE" ]; then
        STALE_HOOKS=""
        while IFS= read -r hook_cmd; do
            # Extract .sh path from command like "bash ~/work/claude/config/hooks/foo.sh"
            hook_path=$(echo "$hook_cmd" | grep -oP '[^ ]*\.sh' | head -1)
            # Expand ~ to $HOME
            hook_path="${hook_path/#\~/$HOME}"
            if [ -n "$hook_path" ] && [ ! -f "$hook_path" ]; then
                STALE_HOOKS="${STALE_HOOKS}$(basename "$hook_path") "
            fi
        done < <(grep -oP '"[^"]*\.sh"' "$SETTINGS_FILE" 2>/dev/null | tr -d '"' | sort -u)
        if [ -n "$STALE_HOOKS" ]; then
            echo -e "  ${YELLOW}⚠ Stale hooks (registered but missing): ${STALE_HOOKS}${NC}"
            WARNINGS="${WARNINGS}STALE_HOOKS;"
        else
            echo -e "  ${GREEN}✓ All registered hooks exist${NC}"
        fi
    fi

    # Check 4: PROTOCOLS.md at repo root (should be in config/)
    if [ -f "$CLAUDE_DIR/PROTOCOLS.md" ]; then
        tokens=$(count_tokens "$CLAUDE_DIR/PROTOCOLS.md")
        echo -e "  ${YELLOW}⚠ PROTOCOLS.md at repo root — wastes ~${tokens} tokens per session${NC}"
        WARNINGS="${WARNINGS}PROTOCOLS_ROOT;"
    fi

    echo ""
    if [ -z "$WARNINGS" ]; then
        echo -e "${GREEN}${BOLD}ALL CHECKS PASSED${NC}"
    else
        echo -e "${YELLOW}${BOLD}WARNINGS: ${WARNINGS}${NC}"
    fi
fi
