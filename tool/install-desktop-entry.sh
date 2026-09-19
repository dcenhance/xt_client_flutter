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

ICON="$HERE/tool/aurum.svg"
PNG="$HOME/.local/share/icons/hicolor/512x512/apps/aurum.png"
APPS="$HOME/.local/share/applications"
mkdir -p "$APPS"

rm -f "$APPS/xtream-player.desktop" "$APPS/orion-player.desktop"

# install the icon into the theme so menus and docks pick it up
if [ -s "$HERE/assets/aurum-mark.png" ]; then
  mkdir -p "$(dirname "$PNG")"
  cp "$HERE/assets/aurum-mark.png" "$PNG"
fi

cat > "$APPS/aurum.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Aurum
Comment=IPTV client for Xtream-Codes panels
Exec=$BIN
Icon=aurum
Terminal=false
Categories=AudioVideo;Player;TV;
StartupWMClass=com.dcenhance.xtream_player
DESKTOP

chmod +x "$APPS/aurum.desktop"
command -v update-desktop-database >/dev/null && update-desktop-database "$APPS" || true
gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
echo "Installed $APPS/aurum.desktop -> $BIN"