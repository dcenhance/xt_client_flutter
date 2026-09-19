#!/usr/bin/env bash
# Installs a KDE/GNOME menu entry pointing at the built Linux bundle.
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$HERE/build/linux/x64/release/bundle/xtream_player"

if [[ ! -x "$BIN" ]]; then
  echo "Binary not found at $BIN" >&2
  echo "Build it first:  flutter build linux --release" >&2
  exit 1
fi

ICON="$HERE/tool/xtream-player.svg"
APPS="$HOME/.local/share/applications"
mkdir -p "$APPS"

cat > "$APPS/xtream-player.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Xtream Player
Comment=IPTV client for Xtream-Codes panels
Exec=$BIN
Icon=$ICON
Terminal=false
Categories=AudioVideo;Player;TV;
StartupWMClass=com.dcenhance.xtream_player
DESKTOP

chmod +x "$APPS/xtream-player.desktop"
command -v update-desktop-database >/dev/null && update-desktop-database "$APPS" || true
echo "Installed $APPS/xtream-player.desktop -> $BIN"