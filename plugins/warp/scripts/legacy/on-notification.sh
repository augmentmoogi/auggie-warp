#!/bin/bash
# Hook script for Auggie Notification event
# Sends a Warp notification when Auggie needs user input

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read hook input from stdin
INPUT=$(cat)

# Extract the notification message
MSG=$(echo "$INPUT" | jq -r '.message // "Input needed"' 2>/dev/null)
[ -z "$MSG" ] && MSG="Input needed"

"$SCRIPT_DIR/warp-notify.sh" "Auggie" "$MSG"
