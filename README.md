# Auggie + Warp

Official [Warp](https://warp.dev) terminal integration for [Auggie](https://docs.augmentcode.com/cli).

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
- **Prompt submitted** — the user sent a message, Auggie is working
- **Tool completed** — a tool call finished, Auggie is back to running
- **Turn ended** — Auggie finished its response

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
- [Auggie](https://docs.augmentcode.com/cli) CLI
- `jq` for JSON parsing (install via `brew install jq` or your package manager)

## How It Works

The plugin communicates with Warp via OSC 777 escape sequences. Each hook script builds a structured JSON payload (via `build-payload.sh`) and sends it to `warp://cli-agent`, where Warp parses it to drive notifications and session UI.

Payloads include a protocol version negotiated between the plugin and Warp (`min(plugin_version, warp_version)`), the session ID, working directory, and event-specific fields.

The plugin registers six hooks:
- **SessionStart** — emits the plugin version and a welcome system message
- **PromptSubmit** — fires when the user submits a prompt, signaling the session is active
- **Stop** — extracts your prompt and Auggie's response, then sends a task-complete notification
- **Notification** — fires when Auggie needs your input
- **PreToolUse** — fires before a tool runs; sends `permission_request` when Auggie is waiting for user input (e.g. `ask-user`)
- **PostToolUse** — fires when a tool call completes

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

The legacy scripts under `plugins/warp/scripts/legacy/` still support
opt-in debug logging. Set `AUGGIE_WARP_DEBUG=1` before launching Auggie:

```bash
AUGGIE_WARP_DEBUG=1 auggie
```

Logs go to `/tmp/auggie-warp-debug.log` (override with
`AUGGIE_WARP_DEBUG_LOG=/path/to/log`).

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
