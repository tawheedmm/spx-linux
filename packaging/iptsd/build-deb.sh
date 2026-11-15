#!/usr/bin/env bash
# Build an arm64 iptsd .deb from a pinned upstream tag (linux-surface/iptsd, GPL-2.0-or-later).
# The touch daemon for the Surface Pro X digitizer; linux-surface publishes x86-64 packages only.
# Needs: git meson ninja-build pkg-config g++ libinih-dev libeigen3-dev libspdlog-dev libfmt-dev
#        libcli11-dev libsystemd-dev dpkg-dev
# Usage: build-deb.sh [OUTDIR]   (default: packaging/out)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${1:-$HERE/../out}
TAG=${IPTSD_TAG:-v3.1.1}
REV=0spx1        # sorts below any distribution 3.1.1-1, so an official package wins
VER=${TAG#v}-$REV
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
mkdir -p "$OUT"

git -c advice.detachedHead=false clone -q --depth 1 -b "$TAG" https://github.com/linux-surface/iptsd.git "$W/src"
COMMIT=$(git -C "$W/src" rev-parse HEAD)
meson setup "$W/build" "$W/src" --prefix=/usr --sysconfdir=/etc --buildtype=release \
  -Ddebug_tools=[] -Dsample_config=true >/dev/null
ninja -C "$W/build" >/dev/null
ST=$W/stage; mkdir -p "$ST"; chmod 755 "$ST"
DESTDIR=$ST meson install -C "$W/build" >/dev/null
rm -rf "$ST/usr/include" "$ST/usr/lib/"*/pkgconfig "$ST/usr/share/pkgconfig"
find "$ST" -type f -perm -u+x -exec sh -c 'file -b "$1" | grep -q ELF && strip --strip-unneeded "$1"' _ {} \;

# runtime dependencies from the binaries' shared libraries
mkdir -p "$W/shl/debian"; printf 'Source: iptsd\n\nPackage: iptsd\nArchitecture: arm64\n' > "$W/shl/debian/control"
BINS=$(find "$ST" -type f -exec sh -c 'file -b "$1" | grep -q ELF && echo "$1"' _ {} \;)
DEPS=$(cd "$W/shl" && dpkg-shlibdeps -O $BINS 2>/dev/null | sed -n 's/^shlibs:Depends=//p')

install -d "$ST/usr/share/doc/iptsd"
cp "$W/src/LICENSE" "$ST/usr/share/doc/iptsd/copyright" 2>/dev/null || true
echo "Built from https://github.com/linux-surface/iptsd tag $TAG (commit $COMMIT) by spx-linux, unmodified." \
  > "$ST/usr/share/doc/iptsd/SOURCE"

mkdir -p "$ST/DEBIAN"
cat > "$ST/DEBIAN/control" <<EOF
Package: iptsd
Version: $VER
Architecture: arm64
Maintainer: spx-linux <noreply@example.invalid>
Depends: $DEPS, udev
Section: utils
Priority: optional
Homepage: https://github.com/linux-surface/iptsd
Description: touch and pen daemon for Microsoft Surface devices (arm64 build)
 Upstream iptsd $TAG, built unmodified for arm64 (Surface Pro X) by spx-linux.
 Processes raw touch and pen data from the digitizer and creates standard
 input devices. Starts automatically for supported devices via udev.
EOF
( cd "$ST" && find etc -type f 2>/dev/null | sed 's|^|/|' ) > "$ST/DEBIAN/conffiles"
[ -s "$ST/DEBIAN/conffiles" ] || rm -f "$ST/DEBIAN/conffiles"
cat > "$ST/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = configure ]; then
  [ -d /run/systemd/system ] && systemctl daemon-reload || true
  command -v udevadm >/dev/null && udevadm control --reload 2>/dev/null || true
fi
EOF
chmod 755 "$ST/DEBIAN/postinst"
dpkg-deb --root-owner-group -Zxz -b "$ST" "$OUT/iptsd_${VER}_arm64.deb" >/dev/null
echo "built $OUT/iptsd_${VER}_arm64.deb (Depends: $DEPS)"
