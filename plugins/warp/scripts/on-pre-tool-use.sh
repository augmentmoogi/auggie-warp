#!/bin/bash
# Hook script for Auggie PreToolUse event
# Sends a "prompt_submit" Warp notification before a tool call runs,
# acting as a workaround for the missing UserPromptSubmit hook in Auggie.
# This re-signals the running state so Warp's in-progress indicator
# stays accurate on turns after the first one.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_LOG="/tmp/auggie-warp-debug.log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] $(basename "$0") pid=$$ TERM_PROGRAM=${TERM_PROGRAM:-} WARP_PROTO=${WARP_CLI_AGENT_PROTOCOL_VERSION:-} WARP_VER=${WARP_CLIENT_VERSION:-}" >> "$_LOG"

source "$SCRIPT_DIR/should-use-structured.sh"

# No legacy equivalent for this hook
if ! should_use_structured; then
    exit 0
fi

source "$SCRIPT_DIR/build-payload.sh"

# Read hook input from stdin
INPUT=$(cat)
echo "[stdin] $INPUT" >> "$_LOG"

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

for _agent in auggie claude; do
    BODY=$(build_payload "$INPUT" "prompt_submit" "$_agent" \
        --arg tool_name "$TOOL_NAME")
    "$SCRIPT_DIR/warp-notify.sh" "warp://cli-agent" "$BODY"
done
