#!/bin/bash
# llm-dispatch.sh — Thin shell wrapper for llm-dispatch.py.
#
# Provides run_llm() for cron scripts. All logic lives in llm-dispatch.py.
#
# Usage: source this file, then call run_llm instead of run_claude_with_timeout.
# No dependencies — calls claude/codex CLIs directly via llm-dispatch.py.

# Resolve the dispatcher .py. NOTE: scripts/ is a symlink into ~/notes, and
# fb:notes refuses .py files, so the dispatcher lives in private_scripts/lib/.
# Prefer the sibling copy (portable checkouts), fall back to private_scripts.
_LLM_DISPATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$_LLM_DISPATCH_DIR/llm-dispatch.py" ]; then
    _LLM_DISPATCH_PY="$_LLM_DISPATCH_DIR/llm-dispatch.py"
else
    _LLM_DISPATCH_PY="$HOME/work/claude/private_scripts/lib/llm-dispatch.py"
fi

# run_llm <job_name> <timeout_secs> <log_file> <prompt> [-- claude-specific args]
run_llm() {
    local _prev_sigpipe
    _prev_sigpipe=$(trap -p SIGPIPE)
    trap '' SIGPIPE

    python3 "$_LLM_DISPATCH_PY" "$@"
    local _rc=$?

    if [ -n "$_prev_sigpipe" ]; then
        eval "$_prev_sigpipe"
    else
        trap - SIGPIPE
    fi
    return $_rc
}
