# Auggie + Warp

Official [Warp](https://warp.dev) terminal integration for [Auggie](https://docs.anthropic.com/en/docs/auggie).

## Features

### 🔔 Native Notifications

Get native Warp notifications when Auggie:
- **Completes a task** — with a summary showing your prompt and Auggie's response
- **Needs your input** — when Auggie has been idle and is waiting for you
- **Requests permission** — when Auggie wants to run a tool and needs your approval

Notifications appear in Warp's notification center and as system notifications, so you can context-switch while Auggie works and get alerted when attention is needed.

### 📡 Session Status

The plugin keeps Warp informed of Auggie's current state by emitting structured events on every session transition:
- **Tool about to run** — Auggie is about to call a tool, session is active
- **Tool completed** — a tool call finished, Auggie is back to running
- **Turn ended** — Auggie finished its response

Note: Auggie does not currently expose a turn-start hook event, so Warp's in-progress indicator only updates on turns that involve tool use. Pure-text replies (e.g., a one-line "hello") will not flip the indicator back to in-progress. This is an upstream Auggie limitation.

This powers Warp's inline status indicators for Auggie sessions.

## Installation

```bash
# In Auggie, add the marketplace
/plugin marketplace add warpdotdev/auggie-warp

# Install the Warp plugin
/plugin install warp@auggie-warp
```

> ⚠️ **Important**: After installing, **restart Auggie or run /reload-plugins** for the plugin to activate.

Once restarted, you'll see a confirmation message and notifications will appear automatically.

## Requirements

- [Warp terminal](https://warp.dev) (macOS, Linux, or Windows)
- [Auggie](https://docs.anthropic.com/en/docs/auggie) CLI
- `jq` for JSON parsing (install via `brew install jq` or your package manager)

## How It Works

The plugin communicates with Warp via OSC 777 escape sequences. Each hook script builds a structured JSON payload (via `build-payload.sh`) and sends it to `warp://cli-agent`, where Warp parses it to drive notifications and session UI.

Payloads include a protocol version negotiated between the plugin and Warp (`min(plugin_version, warp_version)`), the session ID, working directory, and event-specific fields.

The plugin registers six hooks:
- **SessionStart** — emits the plugin version and a welcome system message
- **Stop** — reads the transcript to extract your prompt and Auggie's response, then sends a task-complete notification
- **Notification** (`idle_prompt`) — fires when Auggie has been idle and needs your input
- **PermissionRequest** — fires when Auggie wants to run a tool, includes the tool name and a preview of its input
- **UserPromptSubmit** — fires when you submit a prompt, signaling the session is active again
- **PostToolUse** — fires when a tool call completes, signaling the session is no longer blocked

### Legacy Support

Older Warp clients that predate the structured notification protocol are still supported — they receive plain-text notifications for SessionStart, Stop, and Notification hooks.


## Configuration

Notifications work out of the box. To customize Warp's notification behavior (sounds, system notifications, etc.), see [Warp's notification settings](https://docs.warp.dev/features/notifications).

## Troubleshooting

### Notifications never appear

Auggie only runs plugin hooks when the `enableHooks` feature flag is set.
Add it to `~/.augment/settings.json`:

```json
{
  "enableHooks": true
}
```

Then restart Auggie (or run `/reload-plugins`).

### Enable debug logs

Set `AUGGIE_WARP_DEBUG=1` before launching Auggie to have every hook
invocation append a line to the debug log:

```bash
AUGGIE_WARP_DEBUG=1 auggie
```

By default logs go to `/tmp/auggie-warp-debug.log`. Override the path
with `AUGGIE_WARP_DEBUG_LOG=/path/to/log`. Each entry records the hook
name, PID, Warp env vars, and the JSON payload on a separate `[stdin]`
line.

## Uninstall

```bash
/plugin uninstall warp@auggie-warp
/plugin marketplace remove auggie-warp
```

## Versioning

The plugin version in `plugins/warp/.augment-plugin/plugin.json` is checked by the Warp client to detect outdated installations.
When bumping the version here, also update `MINIMUM_PLUGIN_VERSION` in the Warp client.

## License

MIT License — see [LICENSE](LICENSE) for details.
