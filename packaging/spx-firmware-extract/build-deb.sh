#!/usr/bin/env bash
# Build spx-firmware-extract_<ver>_all.deb. Usage: build-deb.sh [OUTDIR]   (default: packaging/out)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${1:-$HERE/../out}
VER=$(sed -n 's/^VERSION=//p' "$HERE/spx-extract-firmware")
ST=$(mktemp -d); chmod 755 "$ST"; trap 'rm -rf "$ST"' EXIT
mkdir -p "$OUT"
install -D -m755 "$HERE/spx-extract-firmware" "$ST/usr/sbin/spx-extract-firmware"
install -D -m644 "$HERE/firmware-map.tsv"     "$ST/usr/share/spx-firmware-extract/firmware-map.tsv"
install -d "$ST/usr/share/doc/spx-firmware-extract"
cat > "$ST/usr/share/doc/spx-firmware-extract/copyright" <<'EOF'
spx-firmware-extract: MIT License, Copyright (c) 2026 Tawheed Makhdoomi and spx-linux contributors.
This package contains no firmware. It copies firmware from the user's own Windows installation.
EOF
mkdir -p "$ST/DEBIAN"
cat > "$ST/DEBIAN/control" <<EOF
Package: spx-firmware-extract
Version: $VER
Architecture: all
Maintainer: spx-linux <noreply@example.invalid>
Depends: ntfs-3g, util-linux, coreutils
Recommends: linux-firmware-qualcomm-graphics | linux-firmware, linux-firmware-qualcomm-wireless | linux-firmware
Section: admin
Priority: optional
Homepage: https://github.com/tawheedmm/spx-linux
Description: copy Surface Pro X firmware from your own Windows installation
 The DSP, modem, GPU zap shader, Wi-Fi and Bluetooth firmware of the Surface
 Pro X (SQ1) is signed for the device and may not be redistributed. Run
 "sudo spx-extract-firmware" to copy it from your own Windows partition
 (mounted read-only) to /lib/firmware/updates. For a BitLocker-encrypted
 Windows, run extract-firmware.ps1 in Windows first and use --from.
 .
 This package contains no firmware.
EOF
cat > "$ST/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
[ "$1" = configure ] || exit 0
if [ ! -f /var/lib/spx-firmware-extract/manifest.tsv ]; then
  echo "spx-firmware-extract: run 'sudo spx-extract-firmware --dry-run', then 'sudo spx-extract-firmware' to copy the firmware from your Windows partition"
fi
EOF
chmod 755 "$ST/DEBIAN/postinst"
dpkg-deb --root-owner-group -Zxz -b "$ST" "$OUT/spx-firmware-extract_${VER}_all.deb" >/dev/null
echo "built $OUT/spx-firmware-extract_${VER}_all.deb"
