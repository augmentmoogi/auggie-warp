#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: sync-to-local-install.sh [-n|--dry-run] [-h|--help]

Copy the working-copy plugin at <repo>/plugins/warp/ into the local Auggie
marketplace install so changes take effect without a GitHub push + reinstall.

Destination defaults to:
  ~/.augment/plugins/marketplaces/auggie-warp/plugins/warp

Override the install root (the directory containing plugins/warp) with:
  AUGGIE_WARP_INSTALL_DIR=/path/to/install-root

Options:
  -n, --dry-run   Show what would change without writing.
  -h, --help      Show this help.
EOF
}

DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$REPO_ROOT/plugins/warp"

INSTALL_ROOT="${AUGGIE_WARP_INSTALL_DIR:-$HOME/.augment/plugins/marketplaces/auggie-warp}"
DEST="$INSTALL_ROOT/plugins/warp"

if [[ ! -d "$SRC" ]]; then
  echo "error: source directory does not exist: $SRC" >&2
  exit 1
fi

DEST_PARENT="$(dirname "$DEST")"
if [[ ! -d "$DEST_PARENT" ]]; then
  echo "error: destination parent does not exist: $DEST_PARENT" >&2
  echo "       is the auggie-warp plugin installed? expected install root: $INSTALL_ROOT" >&2
  exit 1
fi

sha_of() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo "MISSING"
    return
  fi
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$f" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" | awk '{print $1}'
  else
    echo "error: neither shasum nor sha256sum available" >&2
    exit 1
  fi
}

HOOKS_REL="hooks/hooks.json"
PLUGIN_REL=".augment-plugin/plugin.json"

PRE_HOOKS_SHA="$(sha_of "$DEST/$HOOKS_REL")"
PRE_PLUGIN_SHA="$(sha_of "$DEST/$PLUGIN_REL")"

CHANGED_COUNT=0
if command -v rsync >/dev/null 2>&1; then
  RSYNC_ARGS=(-ai --delete)
  if [[ $DRY_RUN -eq 1 ]]; then
    RSYNC_ARGS+=(--dry-run)
  fi
  RSYNC_OUT="$(rsync "${RSYNC_ARGS[@]}" "$SRC/" "$DEST/")"
  if [[ -n "$RSYNC_OUT" ]]; then
    printf '%s\n' "$RSYNC_OUT"
    CHANGED_COUNT="$(printf '%s\n' "$RSYNC_OUT" | wc -l | tr -d ' ')"
  fi
else
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "dry-run: rsync unavailable; would rm -rf \"$DEST\" && cp -R \"$SRC\" \"$DEST\""
  else
    rm -rf "$DEST"
    cp -R "$SRC" "$DEST"
    CHANGED_COUNT="$(find "$DEST" -type f | wc -l | tr -d ' ')"
  fi
fi

echo
echo "source:      $SRC"
echo "destination: $DEST"
echo "changes:     $CHANGED_COUNT entries"

if [[ $DRY_RUN -eq 1 ]]; then
  echo "(dry run; no files written, skipping restart-reminder check)"
  exit 0
fi

POST_HOOKS_SHA="$(sha_of "$DEST/$HOOKS_REL")"
POST_PLUGIN_SHA="$(sha_of "$DEST/$PLUGIN_REL")"

YELLOW_BOLD=$'\033[1;33m'
GREEN=$'\033[0;32m'
RESET=$'\033[0m'

if [[ "$PRE_HOOKS_SHA" != "$POST_HOOKS_SHA" || "$PRE_PLUGIN_SHA" != "$POST_PLUGIN_SHA" ]]; then
  printf "%s\n" "${YELLOW_BOLD}⚠  hooks.json or plugin.json changed — restart Auggie for these to take effect.${RESET}"
else
  printf "%s\n" "${GREEN}✓ no hooks.json / plugin.json change — no restart needed.${RESET}"
fi
