#!/usr/bin/env bash
# Builds every Linux distribution format from the release bundle:
#   .tar.gz  .tar.xz  .deb  .rpm  .AppImage
# Usage: tool/package-linux.sh     (run after: flutter build linux --release)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(grep '^version:' "$ROOT/pubspec.yaml" | awk '{print $2}' | cut -d+ -f1)"
NAME="xtream-player"
ARCH_RAW="$(uname -m)"
case "$ARCH_RAW" in
  x86_64) DEB_ARCH=amd64; RPM_ARCH=x86_64; APPIMAGE_ARCH=x86_64 ;;
  aarch64) DEB_ARCH=arm64; RPM_ARCH=aarch64; APPIMAGE_ARCH=aarch64 ;;
  *) DEB_ARCH="$ARCH_RAW"; RPM_ARCH="$ARCH_RAW"; APPIMAGE_ARCH="$ARCH_RAW" ;;
esac
SLUG="$NAME-$VERSION-linux-$ARCH_RAW"
BUNDLE="$ROOT/build/linux/x64/release/bundle"
OUT="$ROOT/build/dist"
TOOLS="${TOOLS_DIR:-$HOME/.cache/tools}"

[[ -x "$BUNDLE/xtream_player" ]] || { echo "build the bundle first: flutter build linux --release" >&2; exit 1; }
mkdir -p "$OUT"
rm -f "$OUT/$SLUG".* "$OUT/${NAME}_${VERSION}_"* "$OUT/${NAME}-${VERSION}-1".*

echo "== normalising RPATHs (Flutter leaves absolute build paths in plugin .so files)"
PATCHED="$ROOT/build/linux/x64/release/bundle-packaged"
rm -rf "$PATCHED"
cp -r "$BUNDLE" "$PATCHED"
if command -v patchelf >/dev/null; then
  # $ORIGIN for files in lib/ resolves to lib/, which is where the bundle keeps
  # its shared objects — this also makes rpath checks (rpmbuild) pass.
  for so in "$PATCHED"/lib/*.so; do
    patchelf --set-rpath '$ORIGIN' "$so" 2>/dev/null || true
  done
  patchelf --set-rpath '$ORIGIN/lib' "$PATCHED/xtream_player" 2>/dev/null || true
else
  echo "   warning: patchelf missing; .rpm build may fail its rpath check" >&2
fi
BUNDLE="$PATCHED"

echo "== icon + desktop entry"
magick -background none "$ROOT/tool/xtream-player.svg" -resize 256x256 "$OUT/$NAME.png"
cat > "$OUT/$NAME.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Xtream Player
Comment=IPTV client for Xtream-Codes panels
Exec=$NAME
Icon=$NAME
Terminal=false
Categories=AudioVideo;Player;TV;
StartupWMClass=com.dcenhance.xtream_player
DESKTOP

echo "== portable tarballs"
STAGE="$(mktemp -d)"
cp -r "$BUNDLE" "$STAGE/$SLUG"
tar -czf "$OUT/$SLUG.tar.gz" -C "$STAGE" "$SLUG"
tar -cJf "$OUT/$SLUG.tar.xz" -C "$STAGE" "$SLUG"
rm -rf "$STAGE"

echo "== .deb"
DEBROOT="$(mktemp -d)"
install -d "$DEBROOT/opt/$NAME" "$DEBROOT/usr/bin" \
           "$DEBROOT/DEBIAN" \
           "$DEBROOT/usr/share/applications" \
           "$DEBROOT/usr/share/icons/hicolor/256x256/apps" \
           "$DEBROOT/usr/share/doc/$NAME"
cp -r "$BUNDLE/." "$DEBROOT/opt/$NAME/"
ln -s "/opt/$NAME/xtream_player" "$DEBROOT/usr/bin/$NAME"
cp "$OUT/$NAME.png" "$DEBROOT/usr/share/icons/hicolor/256x256/apps/$NAME.png"
sed "s|^Exec=.*|Exec=/opt/$NAME/xtream_player|" "$OUT/$NAME.desktop" \
  > "$DEBROOT/usr/share/applications/$NAME.desktop"
SIZE="$(du -sk "$DEBROOT/opt/$NAME" | cut -f1)"
cat > "$DEBROOT/DEBIAN/control" <<CONTROL
Package: $NAME
Version: $VERSION
Section: video
Priority: optional
Architecture: $DEB_ARCH
Installed-Size: $SIZE
Maintainer: dcenhance <dcenhance@users.noreply.github.com>
Depends: libgtk-3-0 | libgtk-3-0t64, libmpv2 | libmpv1 | libmpv-dev, libstdc++6, libc6
Homepage: https://github.com/dcenhance/xt_client_flutter
Description: IPTV client for Xtream-Codes panels
 Plays live TV, movies and series from an Xtream-Codes compatible panel.
 Dark, D-pad friendly UI for Linux, Windows, Android, iOS and macOS.
CONTROL
dpkg-deb --build --root-owner-group "$DEBROOT" "$OUT/${NAME}_${VERSION}_${DEB_ARCH}.deb" >/dev/null
rm -rf "$DEBROOT"

echo "== .rpm"
RPMTOP="$(mktemp -d)"
mkdir -p "$RPMTOP"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
SPEC="$RPMTOP/SPECS/$NAME.spec"
cat > "$SPEC" <<SPECFILE
Name:           $NAME
Version:        $VERSION
Release:        1%{?dist}
Summary:        IPTV client for Xtream-Codes panels
License:        MIT
URL:            https://github.com/dcenhance/xt_client_flutter
Requires:       gtk3, mpv-libs, libstdc++
BuildArch:      $RPM_ARCH
%description
Plays live TV, movies and series from an Xtream-Codes compatible panel.
Dark, D-pad friendly UI for Linux, Windows, Android, iOS and macOS.

%install
rm -rf %{buildroot}
install -d %{buildroot}/opt/$NAME %{buildroot}/usr/bin \\
           %{buildroot}/usr/share/applications \\
           %{buildroot}/usr/share/icons/hicolor/256x256/apps
cp -r $BUNDLE/. %{buildroot}/opt/$NAME/
ln -s /opt/$NAME/xtream_player %{buildroot}/usr/bin/$NAME
sed "s|^Exec=.*|Exec=/opt/$NAME/xtream_player|" $OUT/$NAME.desktop \\
  > %{buildroot}/usr/share/applications/$NAME.desktop
cp $OUT/$NAME.png %{buildroot}/usr/share/icons/hicolor/256x256/apps/$NAME.png

%files
/opt/$NAME
/usr/bin/$NAME
/usr/share/applications/$NAME.desktop
/usr/share/icons/hicolor/256x256/apps/$NAME.png

%changelog
* Mon Sep 21 2026 dcenhance <dcenhance@users.noreply.github.com> - $VERSION-1
- Initial package
SPECFILE
rpmbuild --define "_topdir $RPMTOP" -bb "$SPEC" >/dev/null
find "$RPMTOP/RPMS" -name '*.rpm' -exec cp {} "$OUT/" \;
rm -rf "$RPMTOP"

echo "== .AppImage"
APPDIR="$ROOT/build/appimage/AppDir"
rm -rf "$APPDIR"
install -d "$APPDIR/usr/bin"
cp -r "$BUNDLE/." "$APPDIR/usr/bin/"
# bundle libmpv so the AppImage does not depend on the host providing it
MPV_LIB="$(ldconfig -p | sed -n 's|.*=> \(.*/libmpv\.so\.2\)$|\1|p' | head -n 1)"
if [[ -n "$MPV_LIB" && -e "$MPV_LIB" ]]; then
  cp -L "$MPV_LIB" "$APPDIR/usr/bin/lib/libmpv.so.2"
else
  echo "   warning: no system libmpv.so.2 found; the AppImage will need one on the host" >&2
fi
cp "$OUT/$NAME.png" "$APPDIR/$NAME.png"
sed "s|^Exec=.*|Exec=xtream_player|" "$OUT/$NAME.desktop" > "$APPDIR/$NAME.desktop"
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/bin/xtream_player" "$@"
APPRUN
chmod +x "$APPDIR/AppRun"
if [[ -x "$TOOLS/appimagetool" ]]; then
  if ! ARCH="$APPIMAGE_ARCH" "$TOOLS/appimagetool" --no-appstream \
        "$APPDIR" "$OUT/$SLUG.AppImage" >"$OUT/appimagetool.log" 2>&1; then
    echo "   appimagetool failed:" >&2
    tail -n 15 "$OUT/appimagetool.log" >&2
    rm -f "$OUT/$SLUG.AppImage"
  fi
else
  echo "   appimagetool not found in $TOOLS — skipping AppImage" >&2
fi
rm -rf "$ROOT/build/appimage"

echo
echo "Artifacts in $OUT:"
ls -lh "$OUT" | awk 'NR>1 {printf "  %-44s %s\n", $9, $5}'