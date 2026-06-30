#!/usr/bin/env bash
#
# LM Dream Aquarium — HD video screensaver installer for Linux Mint / MATE.
#
# Installs a looping 1080p coral-reef aquarium as a native MATE screensaver
# ("Aquarium HD"). It plays the video with mpv (hardware-decoded) into the
# screensaver window, so it shows up in the normal Mint screensaver chooser.
#
#   Run as your normal user (NOT with sudo). The script calls sudo itself
#   only for the few steps that touch system directories / apt.
#
#   curl -fsSL https://raw.githubusercontent.com/VonHoltenCodes/LM_Dream_Aquarium/main/install.sh | bash
#   -- or --
#   git clone https://github.com/VonHoltenCodes/LM_Dream_Aquarium.git
#   cd LM_Dream_Aquarium && ./install.sh
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Config (override via environment if you like)
# ---------------------------------------------------------------------------
VIDEO_URL="${AQUARIUM_VIDEO_URL:-https://github.com/VonHoltenCodes/LM_Dream_Aquarium/releases/download/v1.0/aquarium.mp4}"
VIDEO_SHA256="${AQUARIUM_VIDEO_SHA256:-1d4b3fa9a08816a924ec58da4c69b45675af22b63ce56a4265391db5897c0c92}"
RAW_BASE="${AQUARIUM_RAW_BASE:-https://raw.githubusercontent.com/VonHoltenCodes/LM_Dream_Aquarium/main}"

VIDEO_DIR="/opt/aquarium-screensaver"
VIDEO_PATH="$VIDEO_DIR/aquarium.mp4"
ENGINE_PATH="/usr/libexec/xscreensaver/aquarium-hack"
THEME_PATH="/usr/share/applications/screensavers/reef2.desktop"
THEME_ID="screensavers-reef2"

# Where this script lives, if run from a git clone (else empty -> download bits)
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")" 2>/dev/null && pwd || true)"

c_grn=$'\e[32m'; c_yel=$'\e[33m'; c_red=$'\e[31m'; c_cyn=$'\e[36m'; c_rst=$'\e[0m'
say()  { printf '%s==>%s %s\n' "$c_cyn" "$c_rst" "$*"; }
ok()   { printf '%s ✓ %s%s\n' "$c_grn" "$*" "$c_rst"; }
warn() { printf '%s ! %s%s\n' "$c_yel" "$*" "$c_rst"; }
die()  { printf '%s ✗ %s%s\n' "$c_red" "$*" "$c_rst" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
[ "$(id -u)" -ne 0 ] || die "Run this as your normal user, not root/sudo. It will call sudo itself when needed."

command -v gsettings >/dev/null 2>&1 || die "gsettings not found — this installer targets the MATE desktop (Linux Mint MATE)."
if ! gsettings list-schemas 2>/dev/null | grep -q '^org.mate.screensaver$'; then
  warn "org.mate.screensaver schema not found — this looks like it isn't a MATE session."
  warn "The files will still install, but the screensaver chooser is MATE-specific."
fi

say "Checking dependencies (mpv, ffmpeg, curl)..."
NEED=()
for pkg in mpv ffmpeg curl; do command -v "$pkg" >/dev/null 2>&1 || NEED+=("$pkg"); done
if [ "${#NEED[@]}" -gt 0 ]; then
  if command -v apt-get >/dev/null 2>&1; then
    say "Installing: ${NEED[*]} (sudo)"
    sudo apt-get update -qq
    sudo apt-get install -y "${NEED[@]}"
  else
    die "Missing: ${NEED[*]} — no apt-get here. Install them with your package manager and re-run."
  fi
fi
ok "Dependencies present."

# ---------------------------------------------------------------------------
# 1. The video -> /opt/aquarium-screensaver/aquarium.mp4
# ---------------------------------------------------------------------------
verify() { [ -f "$1" ] && [ "$(sha256sum "$1" | cut -d' ' -f1)" = "$VIDEO_SHA256" ]; }

say "Installing aquarium video -> $VIDEO_PATH"
sudo mkdir -p "$VIDEO_DIR"

if sudo test -f "$VIDEO_PATH" && sudo sha256sum "$VIDEO_PATH" | grep -q "^$VIDEO_SHA256"; then
  ok "Correct video already in place — skipping download."
else
  TMP="$(mktemp /tmp/aquarium.XXXXXX.mp4)"
  trap 'rm -f "$TMP"' EXIT
  if [ -n "$SRC_DIR" ] && [ -f "$SRC_DIR/aquarium.mp4" ]; then
    say "Using local aquarium.mp4 from the clone."
    cp "$SRC_DIR/aquarium.mp4" "$TMP"
  else
    say "Downloading video (~570 MB) from:"
    printf '    %s\n' "$VIDEO_URL"
    curl -fL --retry 3 -C - -o "$TMP" "$VIDEO_URL" \
      || die "Download failed. Check the URL, or set AQUARIUM_VIDEO_URL to your own host."
  fi
  say "Verifying checksum..."
  if [ -n "$VIDEO_SHA256" ]; then
    verify "$TMP" || die "Checksum mismatch — download is corrupt or the file changed. Aborting."
    ok "Checksum verified."
  else
    warn "No checksum configured — skipping verification."
  fi
  sudo install -m 0644 "$TMP" "$VIDEO_PATH"
  rm -f "$TMP"; trap - EXIT
fi
ok "Video installed."

# ---------------------------------------------------------------------------
# 2. The engine -> /usr/libexec/xscreensaver/aquarium-hack
#    (MUST live here — mate-screensaver silently rejects engines elsewhere)
# ---------------------------------------------------------------------------
say "Installing engine -> $ENGINE_PATH"
sudo mkdir -p "$(dirname "$ENGINE_PATH")"
if [ -n "$SRC_DIR" ] && [ -f "$SRC_DIR/engine/aquarium-hack" ]; then
  sudo install -m 0755 "$SRC_DIR/engine/aquarium-hack" "$ENGINE_PATH"
else
  curl -fsSL "$RAW_BASE/engine/aquarium-hack" | sudo install -m 0755 /dev/stdin "$ENGINE_PATH"
fi
ok "Engine installed."

# ---------------------------------------------------------------------------
# 3. The theme -> /usr/share/applications/screensavers/reef2.desktop
# ---------------------------------------------------------------------------
say "Installing theme -> $THEME_PATH"
sudo mkdir -p "$(dirname "$THEME_PATH")"
if [ -n "$SRC_DIR" ] && [ -f "$SRC_DIR/theme/reef2.desktop" ]; then
  sudo install -m 0644 "$SRC_DIR/theme/reef2.desktop" "$THEME_PATH"
else
  curl -fsSL "$RAW_BASE/theme/reef2.desktop" | sudo install -m 0644 /dev/stdin "$THEME_PATH"
fi
ok "Theme installed (chooser name: \"Aquarium HD\")."

# ---------------------------------------------------------------------------
# 4. Select it via gsettings (runs as YOU, in your session)
# ---------------------------------------------------------------------------
say "Selecting the screensaver..."
gsettings set org.mate.screensaver mode 'single'
gsettings set org.mate.screensaver themes "['$THEME_ID']"
gsettings set org.mate.screensaver idle-activation-enabled true
ok "Selected \"Aquarium HD\" as the active screensaver."

# ---------------------------------------------------------------------------
# 5. Restart the screensaver daemon so the change takes effect now
# ---------------------------------------------------------------------------
if [ -n "${DISPLAY:-}" ]; then
  say "Restarting mate-screensaver daemon..."
  kill "$(pidof mate-screensaver 2>/dev/null)" 2>/dev/null || true
  setsid /usr/bin/mate-screensaver >/dev/null 2>&1 < /dev/null &
  ok "Daemon restarted."
fi

echo
ok "Done! \"Aquarium HD\" is installed and selected."
echo "   • Preview now:    mate-screensaver-command --preview"
echo "   • Test activate:  mate-screensaver-command --activate"
echo "   • Chooser:        Menu → Preferences → Screensaver"
echo
echo "If the screen blanks black instead of showing the video, your display is"
echo "powering down before the video shows. Disable DPMS/blanking with:"
echo "   xset s off; xset -dpms; xset s noblank"
