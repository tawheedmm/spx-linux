#!/usr/bin/env bash
# Build linux-surface/iptsd natively (arm64, Ubuntu noble) and stage an install tree for the Surface.
# Run as root in WSL (installs build deps). Output: $STAGE (default ~/src/iptsd-stage)
set -euo pipefail
SRC=${SRC:-$HOME/src/iptsd}
STAGE=${STAGE:-$HOME/src/iptsd-stage}
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git meson ninja-build pkg-config g++ \
  libinih-dev libeigen3-dev libspdlog-dev libfmt-dev libcli11-dev libsystemd-dev >/dev/null
if [ ! -d "$SRC/.git" ]; then
  git clone --depth 1 https://github.com/linux-surface/iptsd.git "$SRC"
else
  git -C "$SRC" pull --ff-only
fi
echo "== iptsd $(git -C "$SRC" log -1 --format='%h %cs %s')"
echo "== meson options:"; grep -E "^option\(" "$SRC/meson_options.txt" | sed "s/option('\([^']*\)'.*/  \1/"
cd "$SRC"
rm -rf build
meson setup build --prefix=/usr --sysconfdir=/etc --buildtype=release -Ddebug_tools=[] >/dev/null 2>&1 \
  || meson setup build --prefix=/usr --sysconfdir=/etc --buildtype=release >/dev/null
ninja -C build >/dev/null
rm -rf "$STAGE"; DESTDIR="$STAGE" meson install -C build >/dev/null
echo "== staged files"; (cd "$STAGE" && find . -type f | sort)
echo "== runtime libs"; ldd "$STAGE/usr/bin/iptsd" | awk '{print $1}' | grep -v -E 'linux-vdso|ld-linux'
echo "== configs mentioning 0996 / Pro X"; grep -rl -i -E '0996|pro ?x' "$STAGE/usr/share/iptsd" "$SRC/etc" 2>/dev/null | head
