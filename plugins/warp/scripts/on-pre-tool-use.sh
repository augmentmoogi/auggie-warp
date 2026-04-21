#!/bin/bash
# Hook script for Auggie PreToolUse event
# Sends a "prompt_submit" Warp notification before a tool call runs,
# acting as a workaround for the missing UserPromptSubmit hook in Auggie.
# This re-signals the running state so Warp's in-progress indicator
# stays accurate on turns after the first one.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/should-use-structured.sh"

# No legacy equivalent for this hook
if ! should_use_structured; then
    exit 0
fi

source "$SCRIPT_DIR/build-payload.sh"

# Read hook input from stdin
INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

# ask-user means the agent is waiting for input (plan mode / permission).
# Send "permission_request" so Warp shows the stop sign instead of "in progress".
if [ "$TOOL_NAME" = "ask-user" ]; then
    EVENT="permission_request"
else
    EVENT="prompt_submit"
fi

for _agent in auggie claude; do
    BODY=$(build_payload "$INPUT" "$EVENT" "$_agent" \
        --arg tool_name "$TOOL_NAME")
    "$SCRIPT_DIR/warp-notify.sh" "warp://cli-agent" "$BODY"
done
