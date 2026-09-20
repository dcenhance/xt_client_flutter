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
make_png() {
  local src="$1" dst="$2"
  if command -v magick >/dev/null; then
    magick -background none "$src" -resize 256x256 "$dst"
  elif command -v convert >/dev/null; then
    convert -background none "$src" -resize 256x256 "$dst"
  elif command -v rsvg-convert >/dev/null; then
    rsvg-convert -w 256 -h 256 "$src" -o "$dst"
  else
    echo "   warning: no SVG rasteriser (magick/convert/rsvg-convert); using the SVG as-is" >&2
    cp "$src" "$dst"
  fi
}
make_png "$ROOT/tool/spectre.svg" "$OUT/$NAME.png"
cat > "$OUT/$NAME.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Spectre
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
# libmpv is deliberately NOT bundled.
#
# Two attempts at bundling it both failed:
#   1. Copying libmpv.so.2 alone: the copy is linked against the build host's
#      ffmpeg soname (an Ubuntu runner gives libavcodec.so.60), so on a distro
#      with a different ffmpeg the loader dies before main() — observed on
#      Fedora 44 with the CI-built AppImage.
#   2. Copying libmpv plus its whole dependency closure: it starts, but mpv then
#      aborts on playback with
#        m_config_core.c:571: m_config_cache_from_shadow:
#        Assertion `group_index >= 0' failed
#      because media_kit ends up with two mpv configurations in one process.
#
# The deb and rpm already declare a libmpv dependency and the tar.gz has always
# relied on the system copy, so the AppImage does the same: the host's libmpv is
# used and playback matches a normal install. What is checked instead is that we
# are not shipping one that could shadow the host's.
if [[ -e "$APPDIR/usr/bin/lib/libmpv.so.2" ]]; then
  rm -f "$APPDIR/usr/bin/lib/libmpv.so.2"
fi
if ! ls "$APPDIR/usr/bin/lib/" 2>/dev/null | grep -q '^libmpv\.so'; then
  echo "   AppImage ships no libmpv; the host's is used (mpv-libs / libmpv2)"
fi
# `ldconfig -p | grep -q` would fail under `set -o pipefail` when grep exits
# early and ldconfig takes SIGPIPE, which looked like "no libmpv here".
MPV_PRESENT="$(ldconfig -p | grep -c 'libmpv\.so\.2' || true)"
if [[ "${MPV_PRESENT:-0}" == "0" ]]; then
  echo "   warning: this build host has no libmpv.so.2 - the AppImage will need one on the target" >&2
fi
cp "$OUT/$NAME.png" "$APPDIR/$NAME.png"
sed -e "s|^Exec=.*|Exec=xtream_player|" \
    -e "s|^Comment=.*|Comment=IPTV client for Xtream-Codes panels (needs libmpv)|" \
    "$OUT/$NAME.desktop" > "$APPDIR/$NAME.desktop"
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
# The bundle already finds its own lib/ through RPATH; this covers anything that
# dlopen()s by soname at runtime.
export LD_LIBRARY_PATH="$HERE/usr/bin/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$HERE/usr/bin/xtream_player" "$@"
APPRUN
chmod +x "$APPDIR/AppRun"
if [[ -x "$TOOLS/appimagetool" ]]; then
  AIT_LOG="$OUT/appimagetool.log"
  ait() { ARCH="$APPIMAGE_ARCH" "$TOOLS/appimagetool" "$@" "$APPDIR" "$OUT/$SLUG.AppImage"; }
  if ! ait --no-appstream >"$AIT_LOG" 2>&1; then
    # FUSE is often missing on CI containers — retry through the extract-and-run path
    if ! ait --appimage-extract-and-run --no-appstream >>"$AIT_LOG" 2>&1; then
      echo "   appimagetool failed:" >&2
      tail -n 15 "$AIT_LOG" >&2
      rm -f "$OUT/$SLUG.AppImage"
    fi
  fi
else
  echo "   appimagetool not found in $TOOLS — skipping AppImage" >&2
fi
rm -rf "$ROOT/build/appimage"

echo
echo "Artifacts in $OUT:"
ls -lh "$OUT" | awk 'NR>1 {printf "  %-44s %s\n", $9, $5}'