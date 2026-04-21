#!/bin/bash
# Hook script for Auggie Stop event
# Sends a structured Warp notification when Auggie completes a task

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Opt-in debug logging (set AUGGIE_WARP_DEBUG=1)
if [ -n "${AUGGIE_WARP_DEBUG:-}" ]; then
    _LOG="${AUGGIE_WARP_DEBUG_LOG:-/tmp/auggie-warp-debug.log}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $(basename "$0") pid=$$ TERM_PROGRAM=${TERM_PROGRAM:-} WARP_PROTO=${WARP_CLI_AGENT_PROTOCOL_VERSION:-} WARP_VER=${WARP_CLIENT_VERSION:-}" >> "$_LOG"
fi

source "$SCRIPT_DIR/should-use-structured.sh"

# Legacy fallback for old Warp versions
if ! should_use_structured; then
    [ "$TERM_PROGRAM" = "WarpTerminal" ] && exec "$SCRIPT_DIR/legacy/on-stop.sh"
    exit 0
fi

source "$SCRIPT_DIR/build-payload.sh"

# Read hook input from stdin
INPUT=$(cat)
[ -n "${AUGGIE_WARP_DEBUG:-}" ] && echo "[stdin] $INPUT" >> "${AUGGIE_WARP_DEBUG_LOG:-/tmp/auggie-warp-debug.log}"

# Skip if a stop hook is already active (prevents double-notification)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
    exit 0
fi

# Extract the last user prompt and assistant response from the transcript.
# Small delay to allow Auggie to flush the current turn to the transcript file.
# The Stop hook fires before the transcript is fully written.
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
sleep 0.3
QUERY=""
RESPONSE=""
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    # Get the last human prompt from the transcript.
    # "user" type messages include both human prompts and tool-result messages.
    # Human prompts have content that is either a plain string or an array
    # containing {type:"text"} blocks. Tool-result messages have content arrays
    # containing only {type:"tool_result"} blocks. We filter to messages that
    # have at least one "text" block (or are a plain string).
    QUERY=$(jq -rs '
        [
            .[] | select(.type == "user") |
            if .message.content | type == "string" then .
            elif [.message.content[] | select(.type == "text")] | length > 0 then .
            else empty
            end
        ] | last |
        if .message.content | type == "array"
        then [.message.content[] | select(.type == "text") | .text] | join(" ")
        else .message.content // empty
        end
    ' "$TRANSCRIPT_PATH" 2>/dev/null)

    # Get the last assistant response
    RESPONSE=$(jq -rs '
        [.[] | select(.type == "assistant" and .message.content)] | last |
        [.message.content[] | select(.type == "text") | .text] | join(" ")
    ' "$TRANSCRIPT_PATH" 2>/dev/null)

    # Truncate for notification display
    if [ -n "$QUERY" ] && [ ${#QUERY} -gt 200 ]; then
        QUERY="${QUERY:0:197}..."
    fi
    if [ -n "$RESPONSE" ] && [ ${#RESPONSE} -gt 200 ]; then
        RESPONSE="${RESPONSE:0:197}..."
    fi
fi

BODY=$(build_payload "$INPUT" "stop" \
    --arg query "$QUERY" \
    --arg response "$RESPONSE" \
    --arg transcript_path "$TRANSCRIPT_PATH")

"$SCRIPT_DIR/warp-notify.sh" "warp://cli-agent" "$BODY"
