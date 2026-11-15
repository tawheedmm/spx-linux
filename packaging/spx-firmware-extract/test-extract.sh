#!/usr/bin/env bash
# Sandbox test for spx-extract-firmware: fake Windows DriverStore and a fake extract-firmware.ps1
# output folder; no real partitions, no root needed.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export SPX_DT=$T/dt SPX_FW_STATE=$T/state SPX_FW_MAP=$HERE/firmware-map.tsv
X="bash $HERE/spx-extract-firmware"
fail=0; ok() { echo "ok   - $1"; }; bad() { echo "FAIL - $1"; fail=1; }
mkdir -p $T/dt; printf 'microsoft,cambria\0qcom,sc8180x\0' > $T/dt/compatible

# --- fake Windows root ---
R=$T/win/Windows/System32/DriverStore/FileRepository
inf() {  # $1 dir, $2 inf name, $3 version: UTF-16LE INF like Windows writes
  mkdir -p "$1"; printf '\xff\xfe' > "$1/$2.inf"
  printf '[Version]\r\nSignature="$WINDOWS NT$"\r\nDriverVer = 10/09/2023,%s\r\n' "$3" | iconv -f UTF-8 -t UTF-16LE >> "$1/$2.inf"
}
grep -v '^#' "$HERE/firmware-map.tsv" | while IFS=$'\t' read -r i f d r s; do
  [ -n "$i" ] || continue
  [ "$f" = qcslpi8180.mbn ] && continue                    # optional file missing on purpose
  dir="$R/$i.inf_arm64_aaaa"; [ -f "$dir/$i.inf" ] || inf "$dir" "$i" 1.0.2000.0
  echo "new $f" > "$dir/$f"
done
# an OLDER copy of the ADSP package, which must not be picked
inf "$R/surfaceprox_subextadsp.inf_arm64_0ld" surfaceprox_subextadsp 1.0.100.0
echo "old qcadsp" > "$R/surfaceprox_subextadsp.inf_arm64_0ld/qcadsp8180.mbn"

out=$($X --from $T/win --dest $T/fw 2>&1); rc=$?
[ $rc = 0 ] && ok "extract from a Windows root succeeds" || bad "rc=$rc: $out"
[ "$(cat $T/fw/updates/qcom/sc8180x/microsoft/cambria/qcadsp8180.mbn 2>/dev/null)" = "new qcadsp8180.mbn" ] && ok "newest driver package picked (by DriverVer in a UTF-16 INF)" || bad "wrong package picked"
[ -f $T/fw/updates/qca/crnv21.b71 ] && ok "Bluetooth files under updates/qca" || bad "bt files"
[ "$(cat $T/fw/updates/ath10k/WCN3990/hw1.0/board.bin 2>/dev/null)" = "new bdwlan.b58" ] && ok "ath10k board.bin from bdwlan.b58" || bad "board.bin"
[ ! -e $T/fw/qca ] && ok "nothing written outside updates/ (no clash with linux-firmware)" || bad "wrote outside updates/"
echo "$out" | grep -q 'missing-optional' && ok "missing optional SLPI reported, not fatal" || bad "slpi report"
echo "$out" | grep -q 'ok-newer-driver' && ok "hash differences reported as newer drivers" || bad "hash report"
[ -f $T/state/manifest.tsv ] && grep -q qcmpss8180.mbn $T/state/manifest.tsv && ok "manifest written" || bad "manifest"

# --- model from --model: caspar path ---
$X --from $T/win --dest $T/fw2 --model caspar >/dev/null 2>&1; [ -f $T/fw2/updates/qcom/sc8180x/microsoft/caspar/qcmpss8180_nm.mbn ] && ok "--model caspar uses the caspar directory" || bad "caspar path"

# --- dry run writes nothing ---
$X --from $T/win --dest $T/fw3 --dry-run >/dev/null 2>&1; [ ! -e $T/fw3 ] && ok "dry run writes nothing" || bad "dry run wrote files"

# --- folder written by extract-firmware.ps1 (its default board dir name) ---
P=$T/ps1/qcom/sc8180x/MICROSOFT/SurfaceProX; mkdir -p $P $T/ps1/qca $T/ps1/_staging/ath10k-boards
cp $T/fw/updates/qcom/sc8180x/microsoft/cambria/* $P/; cp $T/fw/updates/qca/* $T/ps1/qca/
echo "new bdwlan.b58" > $T/ps1/_staging/ath10k-boards/bdwlan.b58
$X --from $T/ps1 --dest $T/fw4 >/dev/null 2>&1 && [ -f $T/fw4/updates/qcom/sc8180x/microsoft/cambria/wlanmdsp.mbn ] && [ -f $T/fw4/updates/ath10k/WCN3990/hw1.0/board.bin ] \
  && ok "extract from an extract-firmware.ps1 folder (BitLocker path)" || bad "ps1 folder"

# --- a required file missing fails ---
rm $R/qcwlan8180.inf_arm64_aaaa/wlanmdsp.mbn
$X --from $T/win --dest $T/fw5 >/dev/null 2>&1 && bad "succeeded with a required file missing" || ok "fails when a required file is missing"

# --- unknown machine refuses without --model ---
printf 'acme,x\0' > $T/dt/compatible
$X --from $T/win --dest $T/fw6 >/dev/null 2>&1 && bad "accepted an unknown machine" || ok "refuses an unknown machine"

echo; [ $fail = 0 ] && echo "ALL TESTS PASSED" || { echo "SOME TESTS FAILED"; exit 1; }
