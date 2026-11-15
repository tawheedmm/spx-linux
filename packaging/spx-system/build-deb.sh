#!/usr/bin/env bash
# Build spx-system_<ver>_all.deb: device settings for Linux on the Surface Pro X (SQ1).
# Usage: build-deb.sh [OUTDIR]   (default: packaging/out)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${1:-$HERE/../out}
VER=0.1
ST=$(mktemp -d); chmod 755 "$ST"; trap 'rm -rf "$ST"' EXIT
mkdir -p "$OUT"

cp -a "$HERE/files/." "$ST/"
find "$ST" -type d -exec chmod 755 {} +
find "$ST" -type f -exec chmod 644 {} +
chmod 755 "$ST/usr/sbin/"*
install -d "$ST/usr/share/doc/spx-system"
cat > "$ST/usr/share/doc/spx-system/copyright" <<'EOF'
spx-system: MIT License, Copyright (c) 2026 Tawheed Makhdoomi and spx-linux contributors.
EOF

mkdir -p "$ST/DEBIAN"
cat > "$ST/DEBIAN/control" <<EOF
Package: spx-system
Version: $VER
Architecture: all
Maintainer: spx-linux <noreply@example.invalid>
Depends: rmtfs, tqftpserv, qrtr-tools, initramfs-tools, systemd, init-system-helpers
Recommends: spx-boot, spx-firmware-extract, spx-archive-keyring, iptsd, linux-firmware-qualcomm-graphics | linux-firmware, linux-firmware-qualcomm-wireless | linux-firmware
Section: admin
Priority: optional
Homepage: https://github.com/tawheedmm/spx-linux
Description: device settings for Linux on the Microsoft Surface Pro X (SQ1)
 - modem: rmtfs serves the EFS from blank image files (Windows-on-ARM has no
   modemst partitions; with Ubuntu's default the modem crash-loops)
 - initramfs: MODULES=dep, so DSP and touch drivers probe after /lib/firmware
   is reachable
 - audio: load snd-soc-sdm845 at boot; ALSA modprobe fix for kernels without
   the sequencer
 - apt: block Ubuntu's generic kernels and boot loaders (Ubuntu origin only)
 - touch: reset the digitizer if it missed its reset interrupt at boot
 - Waydroid: keep its network script on nftables
 .
 Writes nothing to the EFI system partition or UEFI variables.
EOF
( cd "$ST" && find etc -type f | sed 's|^|/|' | sort ) > "$ST/DEBIAN/conffiles"
echo "activate-noawait update-initramfs" > "$ST/DEBIAN/triggers"

cat > "$ST/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
[ "$1" = configure ] || exit 0
case "$(tr '\0' '\n' < /proc/device-tree/compatible 2>/dev/null)" in
  *microsoft,cambria*) ;;
  *microsoft,caspar*) echo "spx-system: Surface Pro X SQ1 without modem: untested, please report results" ;;
  *) echo "spx-system: WARNING: this doesn't look like a Surface Pro X SQ1; these settings are meant for it" ;;
esac
# Blank EFS images for rmtfs, only if nothing is there yet (never touch an existing setup)
if [ ! -e /var/lib/rmtfs ] && [ ! -L /var/lib/rmtfs ]; then
  install -d -m 0700 /var/lib/rmtfs
fi
if [ -d /var/lib/rmtfs ] && [ ! -L /var/lib/rmtfs ]; then
  for f in modem_fs1 modem_fs2 modem_fsg; do
    [ -e /var/lib/rmtfs/$f ] || { head -c 2097152 /dev/zero > /var/lib/rmtfs/$f; chmod 600 /var/lib/rmtfs/$f; }
  done
  [ -e /var/lib/rmtfs/modem_fsc ] || { head -c 16384 /dev/zero > /var/lib/rmtfs/modem_fsc; chmod 600 /var/lib/rmtfs/modem_fsc; }
fi
# deb-systemd-helper creates the enable links even without a running systemd (chroots, image builds)
deb-systemd-helper enable spx-touch-check.service >/dev/null || true
[ -d /run/systemd/system ] && systemctl daemon-reload || true
echo "spx-system: settings installed; reboot to apply them (initramfs rebuild is triggered)"
EOF
cat > "$ST/DEBIAN/prerm" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = remove ]; then
  deb-systemd-helper disable spx-touch-check.service >/dev/null || true
fi
EOF
cat > "$ST/DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e
# The EFS images in /var/lib/rmtfs are left in place on purpose (the modem may have written state).
if [ "$1" = purge ]; then
  deb-systemd-helper purge spx-touch-check.service >/dev/null || true
fi
if [ "$1" = remove ] || [ "$1" = purge ]; then
  [ -d /run/systemd/system ] && systemctl daemon-reload || true
fi
EOF
chmod 755 "$ST/DEBIAN/postinst" "$ST/DEBIAN/prerm" "$ST/DEBIAN/postrm"
dpkg-deb --root-owner-group -Zxz -b "$ST" "$OUT/spx-system_${VER}_all.deb" >/dev/null
echo "built $OUT/spx-system_${VER}_all.deb"
