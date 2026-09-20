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

ICON="$HERE/tool/spectre.svg"
PNG="$HOME/.local/share/icons/hicolor/512x512/apps/spectre.png"
APPS="$HOME/.local/share/applications"
mkdir -p "$APPS"

rm -f "$APPS/xtream-player.desktop" "$APPS/orion-player.desktop" "$APPS/aurum.desktop" "$APPS/vermeil.desktop"

# install the icon into the theme so menus and docks pick it up
if [ -s "$HERE/assets/spectre-mark.png" ]; then
  mkdir -p "$(dirname "$PNG")"
  cp "$HERE/assets/spectre-mark.png" "$PNG"
fi

cat > "$APPS/spectre.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Spectre
Comment=IPTV client for Xtream-Codes panels
Exec=$BIN
Icon=spectre
Terminal=false
Categories=AudioVideo;Player;TV;
StartupWMClass=com.dcenhance.xtream_player
DESKTOP

chmod +x "$APPS/spectre.desktop"
command -v update-desktop-database >/dev/null && update-desktop-database "$APPS" || true
gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
echo "Installed $APPS/spectre.desktop -> $BIN"