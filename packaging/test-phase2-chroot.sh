#!/usr/bin/env bash
# Install spx-archive-keyring + spx-system (+ spx-boot) into a throwaway Ubuntu rootfs and check
# the result. Run as root in WSL (arm64). Nothing outside the temp rootfs is changed.
set -uo pipefail
OUT=${1:-$(cd "$(dirname "$0")" && pwd)/out}
SUITE=${SUITE:-noble}
R=$(mktemp -d /tmp/spx-chroot.XXXX); trap 'umount -R "$R/proc" 2>/dev/null; rm -rf "$R"' EXIT
fail=0; ok() { echo "ok   - $1"; }; bad() { echo "FAIL - $1"; fail=1; }

mmdebstrap --quiet --variant=minbase --components=main,universe \
  --include=apt,ca-certificates,systemd,initramfs-tools,kmod,udev \
  "$SUITE" "$R" http://ports.ubuntu.com/ubuntu-ports >/dev/null 2>&1 || { echo "mmdebstrap failed"; exit 1; }
mount -t proc proc "$R/proc"
cp "$OUT"/spx-archive-keyring_*_all.deb "$OUT"/spx-system_*_all.deb "$OUT"/spx-boot_*_arm64.deb "$OUT"/spx-firmware-extract_*_all.deb "$R/tmp/"
# the spx repo itself isn't reachable from the chroot test as a source for packages; keep Ubuntu only for deps
chroot "$R" sh -c 'apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq /tmp/spx-archive-keyring_*.deb /tmp/spx-system_*.deb /tmp/spx-boot_*.deb /tmp/spx-firmware-extract_*.deb' > "$R/tmp/install.log" 2>&1 \
  && ok "apt installs all four with their dependencies" || { bad "install failed"; tail -20 "$R/tmp/install.log"; }

[ -f "$R/usr/share/keyrings/spx-archive-keyring.gpg" ] && ok "keyring installed" || bad "keyring"
grep -q 'URIs: https://tawheedmm.github.io/spx-linux' "$R/etc/apt/sources.list.d/spx-linux.sources" && ok "deb822 source installed" || bad "source file"
chroot "$R" apt-get update -qq 2>"$R/tmp/upd.err"; grep -qiE 'NO_PUBKEY|not signed|BADSIG|InRelease.*(error|invalid)' "$R/tmp/upd.err" && bad "apt update: signature problem: $(head -3 $R/tmp/upd.err)" || ok "apt update accepts the spx-linux repo signature"

for f in modem_fs1 modem_fs2 modem_fsg; do [ "$(stat -c %s $R/var/lib/rmtfs/$f 2>/dev/null)" = 2097152 ] || bad "rmtfs $f"; done
[ "$(stat -c %s $R/var/lib/rmtfs/modem_fsc 2>/dev/null)" = 16384 ] && ok "blank EFS images created (3 x 2 MiB + 16 KiB)" || bad "modem_fsc"
grep -q 'ExecStart=/usr/bin/rmtfs -r -s -o /var/lib/rmtfs' "$R/etc/systemd/system/rmtfs.service.d/spx.conf" && ok "rmtfs drop-in" || bad "rmtfs drop-in"
grep -qx 'MODULES=dep' "$R/etc/initramfs-tools/conf.d/spx.conf" && ok "initramfs MODULES=dep" || bad "initramfs conf"
[ -L "$R/etc/systemd/system/multi-user.target.wants/spx-touch-check.service" ] && ok "touch watchdog enabled" || bad "touch watchdog not enabled"

# apt pin: Ubuntu kernels blocked, Ubuntu linux-firmware and libc headers not
pol() { chroot "$R" apt-cache policy "$1" 2>/dev/null | sed -n 's/ *Candidate: //p'; }
[ "$(pol linux-image-generic)" = "(none)" ] && ok "Ubuntu linux-image-generic blocked" || bad "linux-image-generic candidate: $(pol linux-image-generic)"
[ "$(pol grub-efi-arm64)" = "(none)" ] && ok "Ubuntu grub-efi-arm64 blocked" || bad "grub-efi-arm64 candidate: $(pol grub-efi-arm64)"
c=$(pol linux-firmware); [ -n "$c" ] && [ "$c" != "(none)" ] && ok "linux-firmware still installable ($c)" || bad "linux-firmware blocked"
c=$(pol linux-libc-dev); [ -n "$c" ] && [ "$c" != "(none)" ] && ok "linux-libc-dev still installable" || bad "linux-libc-dev blocked"
c=$(pol linux-image-spx); [ -n "$c" ] && [ "$c" != "(none)" ] && ok "linux-image-spx from spx-linux installable ($c, after switching to testing)" || echo "info - linux-image-spx not visible in the 'stable' suite yet (expected: nothing promoted)"

# spx-boot installed but inactive: hook is a no-op, nothing on any ESP
chroot "$R" /etc/kernel/postinst.d/zz-spx-boot 7.4.0-test >/dev/null 2>&1 && ok "kernel hook is a silent no-op before 'spx-boot install'" || bad "kernel hook failed"
[ ! -e "$R/var/lib/spx-boot/state" ] && ok "spx-boot not activated by package install" || bad "spx-boot state exists"

[ -x "$R/usr/sbin/spx-extract-firmware" ] && chroot "$R" spx-extract-firmware --help >/dev/null 2>&1 && ok "spx-extract-firmware installed and runs" || bad "spx-extract-firmware"

# remove: EFS images stay, watchdog disabled
chroot "$R" sh -c 'DEBIAN_FRONTEND=noninteractive apt-get remove -y -qq spx-system' >/dev/null 2>&1
[ -f "$R/var/lib/rmtfs/modem_fs1" ] && ok "remove keeps the EFS images" || bad "EFS images deleted"
[ ! -e "$R/etc/systemd/system/multi-user.target.wants/spx-touch-check.service" ] && ok "remove disables the touch watchdog" || bad "watchdog still enabled"

echo; [ $fail = 0 ] && echo "ALL TESTS PASSED" || { echo "SOME TESTS FAILED"; exit 1; }
