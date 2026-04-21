#!/bin/bash
# Hook script for Auggie PreToolUse event
# Sends a structured Warp notification before a tool call runs,
# re-signalling the Running state so Warp's in-progress indicator
# stays accurate on turns that use tools (Auggie has no UserPromptSubmit hook).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Opt-in debug logging (set AUGGIE_WARP_DEBUG=1)
if [ -n "${AUGGIE_WARP_DEBUG:-}" ]; then
    _LOG="${AUGGIE_WARP_DEBUG_LOG:-/tmp/auggie-warp-debug.log}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $(basename "$0") pid=$$ TERM_PROGRAM=${TERM_PROGRAM:-} WARP_PROTO=${WARP_CLI_AGENT_PROTOCOL_VERSION:-} WARP_VER=${WARP_CLIENT_VERSION:-}" >> "$_LOG"
fi

source "$SCRIPT_DIR/should-use-structured.sh"

# No legacy equivalent for this hook
if ! should_use_structured; then
    exit 0
fi

source "$SCRIPT_DIR/build-payload.sh"

# Read hook input from stdin
INPUT=$(cat)
[ -n "${AUGGIE_WARP_DEBUG:-}" ] && echo "[stdin] $INPUT" >> "${AUGGIE_WARP_DEBUG_LOG:-/tmp/auggie-warp-debug.log}"

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

for _agent in auggie claude; do
    BODY=$(build_payload "$INPUT" "running" "$_agent" \
        --arg tool_name "$TOOL_NAME")
    "$SCRIPT_DIR/warp-notify.sh" "warp://cli-agent" "$BODY"
done
