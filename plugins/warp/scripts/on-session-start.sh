#!/bin/bash
# Hook script for Auggie SessionStart event
# Shows welcome message, Warp detection status, and emits plugin version

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_LOG="/tmp/auggie-warp-debug.log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] $(basename "$0") pid=$$ TERM_PROGRAM=${TERM_PROGRAM:-} WARP_PROTO=${WARP_CLI_AGENT_PROTOCOL_VERSION:-} WARP_VER=${WARP_CLIENT_VERSION:-}" >> "$_LOG"

source "$SCRIPT_DIR/should-use-structured.sh"

# Legacy fallback for old Warp versions
if ! should_use_structured; then
    exec "$SCRIPT_DIR/legacy/on-session-start.sh"
fi

if ! command -v jq &>/dev/null; then
    cat << 'EOF'
{
  "systemMessage": "🚨 Warp notifications require jq! Install it with your system package manager (e.g. brew install jq, apt install jq) 🚨"
}
EOF
    exit 0
fi
source "$SCRIPT_DIR/build-payload.sh"

# Read hook input from stdin
INPUT=$(cat)
echo "[stdin] $INPUT" >> "$_LOG"

# Read plugin version from plugin.json
PLUGIN_VERSION=$(jq -r '.version // "unknown"' "$SCRIPT_DIR/../.augment-plugin/plugin.json" 2>/dev/null)

# Emit structured notification with plugin version so Warp can track it
for _agent in auggie claude; do
    BODY=$(build_payload "$INPUT" "session_start" "$_agent" \
        --arg plugin_version "$PLUGIN_VERSION")
    "$SCRIPT_DIR/warp-notify.sh" "warp://cli-agent" "$BODY"
done
