#!/usr/bin/env bash
# Copy the allowlisted files of this (private) working repo into the public spx-linux tree,
# scrub machine-specific paths, add the public README/licences, then run a privacy check that
# fails on anything that looks private. Nothing is committed or pushed by this script.
#
# Usage: packaging/export-public.sh [DEST]     (default: ../spx-linux next to this repo)
set -euo pipefail
SRC=$(cd "$(dirname "$0")/.." && pwd)
DEST=${1:-$SRC/../spx-linux}
LIST=$SRC/packaging/public-allowlist.txt

mkdir -p "$DEST"
# start clean, but keep a .git directory if the owner has already created one
find "$DEST" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +

cd "$SRC"
n=0
while IFS= read -r line; do
  line=${line%%#*}; line=$(echo "$line" | xargs)   # strip comments and whitespace
  [ -n "$line" ] || continue
  matched=0
  for f in $line; do
    [ -f "$f" ] || continue
    mkdir -p "$DEST/$(dirname "$f")"; cp -p "$f" "$DEST/$f"; n=$((n+1)); matched=1
  done
  [ "$matched" = 1 ] || { echo "allowlist entry matched nothing: $line" >&2; exit 1; }
done < "$LIST"

# public-only files
cp "$SRC/packaging/public/README.md" "$DEST/README.md"
cp "$SRC/packaging/public/LICENSE" "$DEST/LICENSE"
cp "$SRC/packaging/public/LICENSES.md" "$DEST/LICENSES.md"
cp "$SRC/packaging/public/gitignore" "$DEST/.gitignore"
mkdir -p "$DEST/docs"; cp "$SRC/packaging/public/ROADMAP.md" "$DEST/docs/ROADMAP.md"
# kernel-patches/README.md: drop references to files that are not exported (test DTB diff, audio WIP)
sed -i -e '/uncommitted-test-dtb-variants/d' -e '/(with the diff)/d' -e '/audio work in progress/d' -e '/audio-wip/d' "$DEST/kernel-patches/README.md"
cp "$SRC/packaging/public/CONTRIBUTING.md" "$DEST/CONTRIBUTING.md"
# packaging/README.md: the internal "Rules" section becomes a pointer to CONTRIBUTING.md
sed -i -e '/^## Rules that apply to everything in here/,$d' "$DEST/packaging/README.md"
printf '## Contributing\nSee [../CONTRIBUTING.md](../CONTRIBUTING.md): no firmware or personal data, never touch the\nboot setup without asking, keep patch authorship intact.\n' >> "$DEST/packaging/README.md"
# packaging/README.md: replace the private-repo intro with a public one
sed -i -e '3,9d' "$DEST/packaging/README.md"
sed -i -e '2a\
Design and phases: [../docs/ROADMAP.md](../docs/ROADMAP.md). The kernel workflow lives in\
[../.github/workflows/kernel.yml](../.github/workflows/kernel.yml); publishing needs the\
maintainer'"'"'s approval through the `apt-publish` environment.\
' "$DEST/packaging/README.md"
mkdir -p "$DEST/.github/workflows"
mv "$DEST/packaging/workflows/kernel.yml" "$DEST/.github/workflows/kernel.yml"
rmdir "$DEST/packaging/workflows"

# scrub: derive paths from the script location / environment instead of the owner's machine
# any PROJ= line that mentions the owner's Windows path (plain or ${PROJ:-...} form)
sed -i -e '\|^PROJ=.*/mnt/c/Users/|c\
PROJ=${PROJ:-$(cd "$(dirname "$0")/.." \&\& pwd)}' \
       -e 's|^# Usage (from Windows): wsl .*$|# Usage: SRC=<kernel tree> OUT=<staging dir> scripts/build-kernel.sh|' \
       "$DEST/scripts/build-kernel.sh"
sed -i -e 's|^SRC=/home/builder/src/iptsd$|SRC=${SRC:-$HOME/src/iptsd}|' \
       -e 's|^STAGE=/home/builder/src/iptsd-stage$|STAGE=${STAGE:-$HOME/src/iptsd-stage}|' \
       -e 's|Output: /home/builder/src/iptsd-stage/|Output: $STAGE (default ~/src/iptsd-stage)|' \
       "$DEST/scripts/build-iptsd.sh"
sed -i -e '1,2c\
# Kernel packages for the Surface Pro X SQ1. Design: docs/ROADMAP.md (phase 1).' \
       -e 's|Fallback: decompress in the spx-boot hook, see plan.md §2.2|Fallback: decompress the kernel in the boot hook|' \
       "$DEST/.github/workflows/kernel.yml"
sed -i -e '2s|stage an install tree for the DUT\.|stage an install tree for the Surface.|' "$DEST/scripts/build-iptsd.sh"

echo "exported $n files to $DEST"

# ---------------- privacy check ----------------
cd "$DEST"
fail=0
check() {  # $1 = description, $2 = extended regex
  local hits
  # this script itself is excluded: it contains the patterns as text
  hits=$(grep -rInE --exclude-dir=.git --exclude=export-public.sh -e "$2" . || true)
  if [ -n "$hits" ]; then echo "PRIVACY CHECK FAILED: $1"; echo "$hits" | cut -c1-160 | head -10; fail=1; fi
}
check "MAC address"                 '([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}'
check "owner LAN addresses"         '\b10\.0\.0\.[0-9]{1,3}\b'
check "Apple ID / iCloud address"   '@(icloud|me|mac)\.com'
check "Windows user / local paths"  '(/mnt/c/Users/|C:\\Users\\|/home/builder|tawhe@)'
check "SSH key"                     'ssh-(ed25519|rsa) AAAA'
check "ACPI SOSN value"             'SOSN, *0x0*[1-9A-Fa-f]'
check "raw EDID header"             '00 ff ff ff ff ff ff 00'
check "Wi-Fi credentials"           '^\s*(psk|ssid)=[0-9a-fA-F]{8,}'
check "MSDM / product key"          '\bMSDM\b.*[A-Z0-9]{5}-[A-Z0-9]{5}'
big=$(find . -path ./.git -prune -o -type f -size +1M -print)
[ -z "$big" ] || { echo "PRIVACY CHECK FAILED: files over 1 MB:"; echo "$big"; fail=1; }
bin=$(find . -path ./.git -prune -o -type f \( -iname '*.mbn' -o -iname '*.bin' -o -iname '*.elf' -o -iname '*.dat' -o -iname '*.img' -o -iname '*widevine*' -o -iname '*msdm*' \) -print)
[ -z "$bin" ] || { echo "PRIVACY CHECK FAILED: firmware/binary-looking files:"; echo "$bin"; fail=1; }
for f in $(find . -path ./.git -prune -o -type f -print); do
  if ! grep -qI . "$f" 2>/dev/null && [ -s "$f" ]; then echo "PRIVACY CHECK FAILED: binary file $f"; fail=1; fi
done
[ "$fail" = 0 ] && echo "privacy check: clean" || { echo "privacy check: FAILED (fix before publishing)"; exit 2; }
