#!/bin/bash
# Hook script for Auggie Notification event (idle_prompt only)
# Sends a structured Warp notification when Auggie has been idle

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Opt-in debug logging (set AUGGIE_WARP_DEBUG=1)
if [ -n "${AUGGIE_WARP_DEBUG:-}" ]; then
    _LOG="${AUGGIE_WARP_DEBUG_LOG:-/tmp/auggie-warp-debug.log}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $(basename "$0") pid=$$ TERM_PROGRAM=${TERM_PROGRAM:-} WARP_PROTO=${WARP_CLI_AGENT_PROTOCOL_VERSION:-} WARP_VER=${WARP_CLIENT_VERSION:-}" >> "$_LOG"
fi

source "$SCRIPT_DIR/should-use-structured.sh"

# Legacy fallback for old Warp versions
if ! should_use_structured; then
    [ "$TERM_PROGRAM" = "WarpTerminal" ] && exec "$SCRIPT_DIR/legacy/on-notification.sh"
    exit 0
fi

source "$SCRIPT_DIR/build-payload.sh"

# Read hook input from stdin
INPUT=$(cat)
[ -n "${AUGGIE_WARP_DEBUG:-}" ] && echo "[stdin] $INPUT" >> "${AUGGIE_WARP_DEBUG_LOG:-/tmp/auggie-warp-debug.log}"

# Extract notification-specific fields
NOTIF_TYPE=$(echo "$INPUT" | jq -r '.notification_type // "unknown"' 2>/dev/null)
MSG=$(echo "$INPUT" | jq -r '.message // "Input needed"' 2>/dev/null)
[ -z "$MSG" ] && MSG="Input needed"

for _agent in auggie claude; do
    BODY=$(build_payload "$INPUT" "$NOTIF_TYPE" "$_agent" \
        --arg summary "$MSG")
    "$SCRIPT_DIR/warp-notify.sh" "warp://cli-agent" "$BODY"
done
