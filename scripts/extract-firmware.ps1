<#
.SYNOPSIS
  Copy the Surface Pro X (SQ1, sc8180xp) firmware blobs Linux needs out of the
  Windows DriverStore into firmware\<linux-path>, and write a manifest.

.DESCRIPTION
  Read-only with respect to Windows: it only reads from
  C:\Windows\System32\DriverStore\FileRepository and writes under -DestRoot
  (default: <project>\firmware, which is gitignored). No admin rights needed.

  The blobs are signed for this device family and are NOT redistributable.
  Never commit them. See docs\workstreams\firmware.md for the mapping.

  Conversions this script does NOT do (they need Linux tools, run in WSL):
    * ath10k board-2.bin: encode one bdwlan.bXX with ath10k-bdencoder
      (qca-swiss-army-knife). The raw bdwlan files are staged in
      _staging\ath10k-boards\.
    * firmware-5.bin, a630_sqe.fw, a640_gmu.bin come from linux-firmware,
      not from Windows.
  No pil-squasher step is needed: every sc8180x .mbn in the DriverStore is
  already a single-file (squashed) ELF.

.PARAMETER DestRoot
  Output root. Default: <project>\firmware

.PARAMETER BoardDir
  Board-specific firmware dir, relative to DestRoot. Must match the
  firmware-name properties in our DTS. Default follows the mainline
  qcom/<soc>/<VENDOR>/<product>/ convention (cf. qcom/sc8180x/LENOVO/82AK,
  qcom/sc8280xp/MICROSOFT/SurfacePro9). Open question: see firmware.md.

.PARAMETER IncludeOptional
  Also copy blobs no mainline sc8180x driver uses yet (SLPI, IPA, camera ICP,
  wdsp, modem qdb/MCFG, audio ACDB) for future work.

.PARAMETER BtCompatCopies
  Also write qca/crbtfw01.tlv + qca/crnv01.* copies (the linux-surface repo
  ships these as symlinks; some older kernels asked for the 01 names).

.PARAMETER DryRun
  Print what would be copied, copy nothing.
#>
[CmdletBinding()]
param(
    [string]$DestRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) 'firmware'),
    [string]$BoardDir = 'qcom/sc8180x/MICROSOFT/SurfaceProX',
    [switch]$IncludeOptional,
    [switch]$BtCompatCopies,
    [switch]$DryRun
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'
$Repo = 'C:\Windows\System32\DriverStore\FileRepository'

# Pick the package folder for an INF name. If several versions are present,
# take the one with the highest DriverVer (that is the one Windows uses).
function Get-PackageDir([string]$InfName) {
    $dirs = @(Get-ChildItem $Repo -Directory -Filter "$InfName.inf_arm64_*" -ErrorAction SilentlyContinue)
    if ($dirs.Count -eq 0) { return $null }
    $best = $null; $bestVer = [version]'0.0'
    foreach ($d in $dirs) {
        $inf = Join-Path $d.FullName "$InfName.inf"
        $ver = [version]'0.0'
        if (Test-Path $inf) {
            $line = Select-String -Path $inf -Pattern '^\s*DriverVer\s*=' | Select-Object -First 1
            if ($line -and $line.Line -match ',\s*([\d\.]+)') { try { $ver = [version]$Matches[1] } catch {} }
        }
        if ($null -eq $best -or $ver -gt $bestVer) { $best = $d; $bestVer = $ver }
    }
    return $best.FullName
}

# Map: Inf package, source file, Linux destination (relative), required?, expected SHA256
# (SHA256 measured on this machine 2026-11-11; a mismatch is a warning, not an error,
#  because Windows Update can ship newer drivers.)
$B = $BoardDir.TrimEnd('/')
$map = @(
  # --- Remoteprocs (qcom_q6v5_pas) ---
  @{ Inf='surfaceprox_subextadsp'; Src='qcadsp8180.mbn';    Dst="$B/qcadsp8180.mbn";    Req=$true;  Sha='09c06fe8e1c1e6c2c77cd2bbea754b34216a36f56ba9f9a7a3814cd2c31744d3' }
  @{ Inf='surfaceprox_subextcdsp'; Src='qccdsp8180.mbn';    Dst="$B/qccdsp8180.mbn";    Req=$true;  Sha='2a276b79208e89c3299fa81a39ab47bc61a67b8ba13de2a5685f4a9d67d149c1' }
  @{ Inf='surfaceprox_subextmpss'; Src='qcmpss8180.mbn';    Dst="$B/qcmpss8180.mbn";    Req=$true;  Sha='9ec7b6c6dae5d97af84ab71af6cb93b1892a4db1bd2b0b9de3e12a5d691a5439' }
  @{ Inf='surfaceprox_subextmpss'; Src='qcmpss8180_nm.mbn'; Dst="$B/qcmpss8180_nm.mbn"; Req=$true;  Sha='2152816789c4b45c6687aac92d0d3d997197fb41bd1818d6af92bee135457975' }
  # --- GPU zap shader (drm/msm a6xx) ---
  @{ Inf='qcdx8180';               Src='qcdxkmsuc8180.mbn'; Dst="$B/qcdxkmsuc8180.mbn"; Req=$true;  Sha='9c47234c2ffcd5337b4dbf1d82bb587b99afb9e523af959cc9dbb1a6338e62a8' }
  # --- Wi-Fi (ath10k_snoc, WCN3990; firmware runs on the modem Q6, fetched via tqftpserv) ---
  @{ Inf='qcwlan8180';             Src='wlanmdsp.mbn';      Dst="$B/wlanmdsp.mbn";      Req=$true;  Sha='be774cfa5f0cdbdc333819186a162685cc7c63e7823e9e8ca25594974c121887' }
  # --- Video (venus; sc8180x venus is not upstream yet) ---
  @{ Inf='qcdx8180';               Src='qcvss8180.mbn';     Dst="$B/qcvss8180.mbn";     Req=$true;  Sha='891997ec156db83ca660359a30a7c139a923d9b9783ead523051816303614a68' }
  @{ Inf='qcdx8180';               Src='qcvss8180.mbn';     Dst='qcom/venus-5.2/venus.mbn'; Req=$false; Sha='891997ec156db83ca660359a30a7c139a923d9b9783ead523051816303614a68' }
  # --- Bluetooth (hci_qca, WCN3990 rom 2.1) ---
  @{ Inf='qcbtfmuart8180';         Src='crbtfw21.tlv';      Dst='qca/crbtfw21.tlv';     Req=$true;  Sha='b393b6377bd86c5834c59681a4143f8c9954198911d6665448006f18a3d64fe1' }
  @{ Inf='qcbtfmuart8180';         Src='crnv21.bin';        Dst='qca/crnv21.bin';       Req=$true;  Sha='b803e66675b06e4a18ffa0c41611e4792ee62c362e6d12f23610e53b2b9be08a' }
  @{ Inf='qcbtfmuart8180';         Src='crnv21.b3c';        Dst='qca/crnv21.b3c';       Req=$true;  Sha='2fc8074088c2b6961de126db6a8585fdb2174ca2fffee2de140ea71bdb3452a1' }
  @{ Inf='qcbtfmuart8180';         Src='crnv21.b44';        Dst='qca/crnv21.b44';       Req=$true;  Sha='cef4a0ccffdbd5612a82cf99bc0124b6f4e8bd9f390051acd54fbb104a94c964' }
  @{ Inf='qcbtfmuart8180';         Src='crnv21.b45';        Dst='qca/crnv21.b45';       Req=$true;  Sha='2fc8074088c2b6961de126db6a8585fdb2174ca2fffee2de140ea71bdb3452a1' }
  @{ Inf='qcbtfmuart8180';         Src='crnv21.b46';        Dst='qca/crnv21.b46';       Req=$true;  Sha='cef4a0ccffdbd5612a82cf99bc0124b6f4e8bd9f390051acd54fbb104a94c964' }
  @{ Inf='qcbtfmuart8180';         Src='crnv21.b47';        Dst='qca/crnv21.b47';       Req=$true;  Sha='cef4a0ccffdbd5612a82cf99bc0124b6f4e8bd9f390051acd54fbb104a94c964' }
  @{ Inf='qcbtfmuart8180';         Src='crnv21.b71';        Dst='qca/crnv21.b71';       Req=$true;  Sha='cef4a0ccffdbd5612a82cf99bc0124b6f4e8bd9f390051acd54fbb104a94c964' }
)

# ath10k board data files: staged raw, to be encoded into board-2.bin in WSL.
foreach ($f in 'bdwlan.bin','bdwlan.b36','bdwlan.b37','bdwlan.b46','bdwlan.b47','bdwlan.b48','bdwlan.b58','bdwlan.b5f','bdwlan.b71','bdwlanu.b58','bdwlanu.b5f') {
    $map += @{ Inf='qcwlan8180'; Src=$f; Dst="_staging/ath10k-boards/$f"; Req=$true; Sha='' }
}

if ($BtCompatCopies) {
    foreach ($f in 'crbtfw21.tlv','crnv21.bin','crnv21.b3c','crnv21.b44','crnv21.b45','crnv21.b46','crnv21.b47','crnv21.b71') {
        $map += @{ Inf='qcbtfmuart8180'; Src=$f; Dst=('qca/' + ($f -replace '21','01')); Req=$false; Sha='' }
    }
}

if ($IncludeOptional) {
    $map += @(
      @{ Inf='surfaceprox_subextscss'; Src='qcslpi8180.mbn';        Dst="$B/qcslpi8180.mbn";              Req=$false; Sha='7964ffba743cc6c1042faa21ae016c492a733f4de031a087ba2796b1ed354d50' }
      @{ Inf='qcipa8180';              Src='ipa_fws.elf';           Dst="$B/ipa_fws.mbn";                 Req=$false; Sha='510f10022640b99042a05aac6ead42435deb4d4e509ec8f4a78b851b4f911b18' }
      @{ Inf='surfaceprox_auddevext';  Src='qcwdsp8180.mbn';        Dst="$B/qcwdsp8180.mbn";              Req=$false; Sha='9f23485cd116493001c5c3f17f510a4ccc576f4ecb81b37d4a49ac6ba63327c5' }
      @{ Inf='qccamisp8180';           Src='CAMERA_ICP_AAAAAA.elf'; Dst="$B/CAMERA_ICP_AAAAAA.elf";       Req=$false; Sha='2a1ca04a13ff358cb9fbc73c273993979b9309d58b7a99f3f87084a07ff05709' }
      @{ Inf='surfaceprox_subextmpss'; Src='qdsp6m.qdb';            Dst="$B/qdsp6m.qdb";                  Req=$false; Sha='4723a56f5e5d399ed7f0b762617f3d8b9bcfad609e4cc6e2d11785ca4bfd3c93' }
    )
    foreach ($f in 'Bluetooth_cal.acdb','Codec_cal.acdb','General_cal.acdb','Global_cal.acdb','Handset_cal.acdb','Hdmi_cal.acdb','Headset_cal.acdb','Speaker_cal.acdb','workspaceFile.qwsp') {
        $map += @{ Inf='surfaceprox_acsp'; Src=$f; Dst="_staging/acdb/$f"; Req=$false; Sha='' }
    }
    # Modem MCFG: copied raw. Renaming to modem_pr/mcfg/... paths follows the
    # mapping table in linux-surface/aarch64-firmware scripts/getfw.py (see firmware.md).
    $mcfg = Get-PackageDir 'surfaceprox_mcfg'
    if ($mcfg) {
        Get-ChildItem (Join-Path $mcfg 'MCFG') -File | ForEach-Object {
            $map += @{ Inf='surfaceprox_mcfg'; Src=('MCFG\' + $_.Name); Dst="_staging/mcfg/$($_.Name)"; Req=$false; Sha='' }
        }
    }
}

# ---------------------------------------------------------------------------
$pkgCache = @{}
$manifest = New-Object System.Collections.Generic.List[object]
$missing = 0; $mismatch = 0

foreach ($m in $map) {
    if (-not $pkgCache.ContainsKey($m.Inf)) { $pkgCache[$m.Inf] = Get-PackageDir $m.Inf }
    $pkg = $pkgCache[$m.Inf]
    $src = if ($pkg) { Join-Path $pkg $m.Src } else { $null }
    $dst = Join-Path $DestRoot ($m.Dst -replace '/', '\')

    if (-not $src -or -not (Test-Path -LiteralPath $src)) {
        $status = if ($m.Req) { 'MISSING' } else { 'missing(optional)' }
        if ($m.Req) { $missing++ }
        $manifest.Add([pscustomobject]@{ Status=$status; Linux=$m.Dst; Size=''; SHA256=''; Package=$m.Inf; Source=$m.Src })
        continue
    }

    $hash = (Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash.ToLower()
    $size = (Get-Item -LiteralPath $src).Length
    $status = 'ok'
    if ($m.Sha -and $m.Sha -ne $hash) { $status = 'ok(hash-changed)'; $mismatch++ }

    if (-not $DryRun) {
        $dir = Split-Path -Parent $dst
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Copy-Item -LiteralPath $src -Destination $dst -Force
    } else { $status = "dry-run:$status" }

    $manifest.Add([pscustomobject]@{ Status=$status; Linux=$m.Dst; Size=$size; SHA256=$hash; Package=(Split-Path -Leaf $pkg); Source=$m.Src })
}

$manifest | Format-Table Status, Linux, Size, SHA256, Package -AutoSize | Out-String -Width 400 | Write-Output

if (-not $DryRun) {
    $mf = Join-Path $DestRoot 'MANIFEST.tsv'
    "# Extracted $(Get-Date -Format s) from $Repo on $env:COMPUTERNAME. Not redistributable; do not commit." | Set-Content -Path $mf -Encoding utf8
    $manifest | ConvertTo-Csv -Delimiter "`t" -NoTypeInformation | Add-Content -Path $mf -Encoding utf8
    Write-Output "Manifest: $mf"
}

Write-Output ("{0} entries, {1} required missing, {2} hash changed since 2026-11-11." -f $manifest.Count, $missing, $mismatch)
Write-Output 'Still needed from linux-firmware (not in Windows): qcom/a630_sqe.fw, qcom/a640_gmu.bin, ath10k/WCN3990/hw1.0/firmware-5.bin.'
Write-Output 'Still to build in WSL: ath10k/WCN3990/hw1.0/board-2.bin from _staging/ath10k-boards (see docs/workstreams/firmware.md).'
if ($missing -gt 0) { exit 1 }
