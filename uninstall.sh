#!/usr/bin/env bash
#
# LM Dream Aquarium — uninstaller. Removes the screensaver and reverts the
# MATE screensaver selection. Run as your normal user (not sudo).
#
set -euo pipefail

VIDEO_DIR="/opt/aquarium-screensaver"
ENGINE_PATH="/usr/libexec/xscreensaver/aquarium-hack"
THEME_PATH="/usr/share/applications/screensavers/reef2.desktop"

c_grn=$'\e[32m'; c_cyn=$'\e[36m'; c_rst=$'\e[0m'
say() { printf '%s==>%s %s\n' "$c_cyn" "$c_rst" "$*"; }
ok()  { printf '%s ✓ %s%s\n' "$c_grn" "$*" "$c_rst"; }

[ "$(id -u)" -ne 0 ] || { echo "Run as your normal user, not root."; exit 1; }

# Revert the screensaver selection to the MATE default (blank screen).
if command -v gsettings >/dev/null 2>&1; then
  say "Reverting screensaver selection..."
  gsettings set org.mate.screensaver mode 'blank-only' || true
  gsettings reset org.mate.screensaver themes || true
  ok "Reverted to blank-screen default."
fi

say "Removing installed files (sudo)..."
sudo rm -f "$ENGINE_PATH" "$THEME_PATH"
sudo rm -rf "$VIDEO_DIR"
ok "Removed engine, theme, and video."

# Restart the daemon so the change applies now.
if [ -n "${DISPLAY:-}" ]; then
  kill "$(pidof mate-screensaver 2>/dev/null)" 2>/dev/null || true
  setsid /usr/bin/mate-screensaver >/dev/null 2>&1 < /dev/null &
fi

echo
ok "Uninstalled. mpv/ffmpeg were left installed (other apps may use them)."
