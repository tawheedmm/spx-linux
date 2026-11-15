#!/usr/bin/env bash
# Build the spx-boot .deb (arm64). Needs grub-efi-arm64-bin (for grub-mkstandalone) and dpkg-deb.
# Usage: packaging/spx-boot/build-deb.sh [OUTDIR]     (default: packaging/out)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${1:-$HERE/../out}
VER=$(sed -n 's/^VERSION=//p' "$HERE/spx-boot")
PKG=spx-boot_${VER}_arm64
ST=$(mktemp -d); chmod 755 "$ST"; trap 'rm -rf "$ST"' EXIT
mkdir -p "$OUT"

command -v grub-mkstandalone >/dev/null || { echo "grub-mkstandalone missing: apt install grub-efi-arm64-bin"; exit 1; }
GRUBVER=$(dpkg-query -W -f '${Version}' grub-efi-arm64-bin 2>/dev/null || echo unknown)

install -D -m755 "$HERE/spx-boot"     "$ST/usr/sbin/spx-boot"
install -D -m644 "$HERE/default"      "$ST/etc/default/spx-boot"
install -D -m755 "$HERE/zz-spx-boot"  "$ST/etc/kernel/postinst.d/zz-spx-boot"
install -D -m755 "$HERE/zz-spx-boot"  "$ST/etc/kernel/postrm.d/zz-spx-boot"
install -d "$ST/usr/lib/spx-boot" "$ST/usr/share/doc/spx-boot"
# Standalone GRUB with every module in its memdisk (ext2, part_gpt, fat, search, ...); the
# embedded config only finds \EFI\spx\grub.cfg and loads it.
grub-mkstandalone -O arm64-efi --locales= --fonts= --themes= \
  -o "$ST/usr/lib/spx-boot/grubaa64.efi" "boot/grub/grub.cfg=$HERE/grub-stub.cfg"
echo "grub-mkstandalone from grub-efi-arm64-bin $GRUBVER (GPL-3.0-or-later; source: the Ubuntu grub2 source package of that version)" \
  > "$ST/usr/share/doc/spx-boot/GRUB-SOURCE"
cat > "$ST/usr/share/doc/spx-boot/copyright" <<'EOF'
spx-boot: MIT License, Copyright (c) 2026 Tawheed Makhdoomi and spx-linux contributors.
usr/lib/spx-boot/grubaa64.efi: GNU GRUB, GPL-3.0-or-later (see GRUB-SOURCE for the source version).
EOF

mkdir -p "$ST/DEBIAN"
cat > "$ST/DEBIAN/control" <<EOF
Package: spx-boot
Version: $VER
Architecture: arm64
Maintainer: spx-linux <noreply@example.invalid>
Depends: efibootmgr, util-linux, mount
Section: admin
Priority: optional
Homepage: https://github.com/tawheedmm/spx-linux
Description: boot setup for Linux on the Microsoft Surface Pro X (SQ1)
 Installs a standalone GRUB in \EFI\spx on the EFI system partition shared with
 Windows, and keeps its menu in sync with the kernels in /boot (newest, previous,
 safe mode, Windows). Kernels stay on the Linux root filesystem.
 .
 Nothing is written to the EFI partition or the UEFI boot entries until you run
 "sudo spx-boot install", which shows what it will do and asks first.
EOF
printf '/etc/default/spx-boot\n' > "$ST/DEBIAN/conffiles"
cat > "$ST/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = configure ]; then
  if [ -f /var/lib/spx-boot/state ]; then
    spx-boot update || true
  else
    echo "spx-boot: installed. To set up booting (asks before changing anything): sudo spx-boot install --dry-run, then sudo spx-boot install"
  fi
fi
EOF
chmod 755 "$ST/DEBIAN/postinst"
dpkg-deb --root-owner-group -Zxz -b "$ST" "$OUT/$PKG.deb" >/dev/null
echo "built $OUT/$PKG.deb"
