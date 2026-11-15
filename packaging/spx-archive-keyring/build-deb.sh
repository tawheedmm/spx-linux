#!/usr/bin/env bash
# Build spx-archive-keyring_<ver>_all.deb: the apt signing key + the deb822 source for the
# spx-linux repository. Usage: build-deb.sh [OUTDIR]   (default: packaging/out)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${1:-$HERE/../out}
VER=2026.11.13
FPR=A74FDC0FB37A36C3245DCE88D9D97BF93015B90D
ST=$(mktemp -d); chmod 755 "$ST"; trap 'rm -rf "$ST"' EXIT
mkdir -p "$OUT"

# refuse to package a key whose fingerprint doesn't match
G=$(mktemp -d); GNUPGHOME=$G gpg -q --import "$HERE/spx-archive-keyring.gpg" 2>/dev/null
got=$(GNUPGHOME=$G gpg --with-colons --fingerprint | awk -F: '/^fpr/{print $10; exit}')
GNUPGHOME=$G gpgconf --kill gpg-agent 2>/dev/null || true; rm -rf "$G"
[ "$got" = "$FPR" ] || { echo "key fingerprint $got != $FPR"; exit 1; }

install -D -m644 "$HERE/spx-archive-keyring.gpg" "$ST/usr/share/keyrings/spx-archive-keyring.gpg"
install -d "$ST/etc/apt/sources.list.d" "$ST/usr/share/doc/spx-archive-keyring"
cat > "$ST/etc/apt/sources.list.d/spx-linux.sources" <<EOF
# spx-linux: packages for Linux on the Microsoft Surface Pro X (SQ1)
# https://github.com/tawheedmm/spx-linux
# Suites: "stable" (tested releases) or "testing" (every published build). Key fingerprint:
# $FPR
Types: deb
URIs: https://tawheedmm.github.io/spx-linux
Suites: stable
Components: main
Architectures: arm64
Signed-By: /usr/share/keyrings/spx-archive-keyring.gpg
EOF
cat > "$ST/usr/share/doc/spx-archive-keyring/copyright" <<'EOF'
spx-archive-keyring: MIT License, Copyright (c) 2026 Tawheed Makhdoomi and spx-linux contributors.
EOF
mkdir -p "$ST/DEBIAN"
cat > "$ST/DEBIAN/control" <<EOF
Package: spx-archive-keyring
Version: $VER
Architecture: all
Maintainer: spx-linux <noreply@example.invalid>
Section: misc
Priority: optional
Homepage: https://github.com/tawheedmm/spx-linux
Description: apt key and source for the spx-linux repository (Surface Pro X SQ1)
 Installs the signing key (fingerprint $FPR) and
 /etc/apt/sources.list.d/spx-linux.sources pointing at the "stable" suite of
 https://tawheedmm.github.io/spx-linux. Change Suites to "testing" there to
 get every published build.
EOF
printf '/etc/apt/sources.list.d/spx-linux.sources\n' > "$ST/DEBIAN/conffiles"
dpkg-deb --root-owner-group -Zxz -b "$ST" "$OUT/spx-archive-keyring_${VER}_all.deb" >/dev/null
echo "built $OUT/spx-archive-keyring_${VER}_all.deb"
