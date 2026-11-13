#!/usr/bin/env bash
# Build the Surface Pro X kernel inside WSL (native arm64).
# Usage: SRC=<kernel tree> OUT=<staging dir> scripts/build-kernel.sh
set -euo pipefail

PROJ=${PROJ:-$(cd "$(dirname "$0")/.." && pwd)}
SRC=${SRC:-$HOME/src/linux}
OUT=${OUT:-$HOME/src/out}
VARIANT=${VARIANT:-cambria}
JOBS=${JOBS:-$(nproc)}
# Rust (Android binder): versioned Ubuntu toolchain exposed under the plain names
if command -v rustc-1.91 >/dev/null; then
  mkdir -p "$HOME/.local/rustbin"
  for t in rustc rustdoc; do ln -sf "$(command -v $t-1.91)" "$HOME/.local/rustbin/$t"; done
  ln -sf "$(command -v bindgen-0.71)" "$HOME/.local/rustbin/bindgen"
  export PATH="$HOME/.local/rustbin:$PATH"
fi

cd "$SRC"
scripts/kconfig/merge_config.sh -m arch/arm64/configs/defconfig "$PROJ/scripts/spx-cambria.config" ${EXTRA_FRAGMENTS:-} >/dev/null
make -s olddefconfig

# Report fragment options that did not survive (missing symbol or unmet dependency)
echo "== fragment options not applied =="
cat "$PROJ/scripts/spx-cambria.config" ${EXTRA_FRAGMENTS:-} | grep -E '^CONFIG_[A-Z0-9_]+=' | while IFS= read -r line; do
  grep -qx "$line" .config || echo "  $line  (now: $(grep -E "^${line%%=*}=|# ${line%%=*} is not set" .config || echo absent))"
done

# GRUB on arm64 needs the uncompressed EFI-stub Image (it rejects Image.gz)
make -s -j"$JOBS" Image modules dtbs

REL=$(make -s kernelrelease)
rm -rf "$OUT" && mkdir -p "$OUT/boot/dtbs/qcom"
cp arch/arm64/boot/Image "$OUT/boot/vmlinuz-$REL"
cp arch/arm64/boot/dts/qcom/sc8180x-microsoft-*.dtb "$OUT/boot/dtbs/qcom/"
cp .config "$OUT/boot/config-$REL"
make -s modules_install INSTALL_MOD_PATH="$OUT" INSTALL_MOD_STRIP=1
tar -C "$OUT" -I 'zstd -T0' -cf "$HOME/src/spx-$REL.tar.zst" boot lib
echo "== built $REL =="
ls -la "$OUT/boot" "$HOME/src/spx-$REL.tar.zst"
