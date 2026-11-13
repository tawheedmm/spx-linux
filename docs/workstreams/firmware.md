# Firmware map: Surface Pro X (SQ1, sc8180xp, Surface_Pro_X_1876)

Author: firmware-map agent, 2026-11-11. Status: draft for owner review.
Extraction script: `scripts/extract-firmware.ps1` (not run yet). Output goes to `firmware/`, which is gitignored.
**None of these blobs may be committed or redistributed.** They are signed by Qualcomm/Microsoft for this device family.

## Sources
- Windows DriverStore on this machine: `C:\Windows\System32\DriverStore\FileRepository`, read-only scan on 2026-11-11 (Windows 11 26300).
- Mainline `arch/arm64/boot/dts/qcom/sc8180x-lenovo-flex-5g.dts` (master, fetched 2026-11-11) sets `firmware-name` for
  `gpu_zap_shader`, `remoteproc_adsp`, `remoteproc_cdsp` and `remoteproc_mpss` (= `qcmpss8180_nm.mbn`), all under `qcom/sc8180x/LENOVO/82AK/`.
  It sets no firmware-name or calibration variant for wifi, venus or ipa.
- Mainline `sc8180x-primus.dts` uses `qcom/sc8180x/{qcdxkmsuc8180,qcadsp8180,qcmpss8180}.mbn`.
- Mainline `drivers/gpu/drm/msm/adreno/a6xx_catalog.c`: Adreno 680 (chip id 0x06080001) uses `a630_sqe.fw` and `a640_gmu.bin`
  from linux-firmware. The zap shader comes from DT `firmware-name`.
- Mainline `drivers/soc/qcom/qcom_pd_mapper.c` has a `qcom,sc8180x` table (adsp audio/root/charger, cdsp root, mpss gps/wlan).
  Its in-kernel pd-mapper replaces the userspace pd-mapper and its `.jsn` files.
- linux-surface/aarch64-firmware (`scripts/getfw.py` and the git tree, fetched 2026-11-11). This repo covers **only the SQ2**
  (`qcom/msft/surface/pro-x-sq2/`) and reads the same `surfaceprox_*`/`qc*8180` DriverStore packages that this machine has.
  - **Cross-check:** I computed git blob SHA-1s of the local files and compared them with the repo tree.
    These match byte for byte: `qccdsp8180.mbn`, `qcmpss8180.mbn`, `qcmpss8180_nm.mbn`, `qdsp6m.qdb`, `crbtfw21.tlv`, `crnv21.bin` and `crnv21.b44`.
    These differ (different driver builds): `qcadsp8180.mbn` (repo 10758800 B), `qcdxkmsuc8180.mbn`, `qcvss8180.mbn` (repo 1159200 B) and `wlanmdsp.mbn` (repo 4316952 B).
    So SQ1 and SQ2 use the same driver packages, and the SQ2 recipe applies to SQ1.

## Conversion summary
- **No pil-squasher is needed.** Every `.mbn` found is already a single-file ELF32 with all segments inline. No `.mdt`/`.bNN`
  split images exist in the DriverStore. `qcom_q6v5_pas`/`mdt_loader` load these directly.
- **Wi-Fi needs a `board-2.bin`.** The Windows package ships raw board data (`bdwlan.bin`, `.b36`…`.b71`, `bdwlanu.*`, 26328 B each).
  ath10k (WCN3990, snoc) wants `ath10k/WCN3990/hw1.0/board-2.bin`. Build it in WSL with `ath10k-bdencoder` from qca-swiss-army-knife.
  linux-surface encoded `bdwlan.b58` under board name `bus=snoc,qmi-board-id=ff,qmi-chip-id=30224` for the SQ2. The SQ1 board-id and
  chip-id must come from the first ath10k boot log (`qmi chip_id ... board_id ...`). If the board-id is `ff` (unprogrammed), add a
  `qcom,calibration-variant` (formerly `qcom,ath10k-calibration-variant`) string such as `Microsoft_SurfaceProX` to the DTS and encode the
  board file under `...,variant=Microsoft_SurfaceProX`, as the Flex 5G/other WCN3990 laptops upstream do.
- **ath10k `firmware-5.bin` comes from linux-firmware** (`ath10k/WCN3990/hw1.0/firmware-5.bin`). linux-surface modified it with
  `ath10k-fwencoder --modify --features=wowlan,mgmt-tx-by-ref,non-bmi,single-chan-info-per-channel`. Check whether current
  linux-firmware already sets the needed features.
- **Bluetooth needs no conversion.** btqca loads `qca/crbtfw21.tlv` + `qca/crnv21.bin` for WCN3990 rom 2.1. linux-surface also ships `*01*` symlinks;
  the script can write copies of those with `-BtCompatCopies`.
- **Venus:** linux-surface split `qcvss8180.mbn` into `qcom/venus-5.2/venus.mdt/.bNN` and also used it as `venus.mbn`. sc8180x venus is not upstream.

## Mapping table

`<B>` = board dir, script default `qcom/sc8180x/MICROSOFT/SurfaceProX` (open question 1).
Package dirs are under `C:\Windows\System32\DriverStore\FileRepository\`. Where several versions exist, the script picks the highest `DriverVer`;
the one listed is what that resolves to today. SHA256 values are full.

### Required for M1/M2

| Linux path | Windows source (package \ file) | Size | SHA256 | Needed by | Notes |
|---|---|---|---|---|---|
| `<B>/qcadsp8180.mbn` | `surfaceprox_subextadsp.inf_arm64_bbffa45584bbab05\qcadsp8180.mbn` (1.0.1980.1) | 10474240 | `09c06fe8e1c1e6c2c77cd2bbea754b34216a36f56ba9f9a7a3814cd2c31744d3` | `qcom_q6v5_pas` (remoteproc_adsp): audio, battery/charger (pmic_glink), USB-C altmode | ELF32, squashed. Newer than the SQ2 repo copy. |
| `<B>/qccdsp8180.mbn` | `surfaceprox_subextcdsp.inf_arm64_281e1f1391ab7d66\qccdsp8180.mbn` (1.0.1660.1) | 3094036 | `2a276b79208e89c3299fa81a39ab47bc61a67b8ba13de2a5685f4a9d67d149c1` | `qcom_q6v5_pas` (remoteproc_cdsp), fastrpc | Same file as linux-surface SQ2. An older generic copy is in `qcsubsys_ext_cdsp8180.inf_arm64_124267b7a47f52c4` (3081876 B, `be05c17c…5621e`); not used. |
| `<B>/qcmpss8180.mbn` | `surfaceprox_subextmpss.inf_arm64_5bfdec67a8c36b0b\qcmpss8180.mbn` (10400.1.77.0) | 75470832 | `9ec7b6c6dae5d97af84ab71af6cb93b1892a4db1bd2b0b9de3e12a5d691a5439` | `qcom_q6v5_pas` (remoteproc_mpss): LTE modem **and** Wi-Fi (WCN3990 firmware runs on the MPSS) | Same as SQ2. Primus uses this name. |
| `<B>/qcmpss8180_nm.mbn` | same package `\qcmpss8180_nm.mbn` | 5217520 | `2152816789c4b45c6687aac92d0d3d997197fb41bd1818d6af92bee135457975` | remoteproc_mpss, no-modem build (Wi-Fi/GPS only) | Flex 5G DTS uses `_nm`. Good first choice for M2 Wi-Fi: no MCFG/rmtfs EFS needed. |
| `<B>/qcdxkmsuc8180.mbn` | `qcdx8180.inf_arm64_9b83a2ef84864dd7\qcdxkmsuc8180.mbn` (27.20.2140.0, in use) | 14240 | `9c47234c2ffcd5337b4dbf1d82bb587b99afb9e523af959cc9dbb1a6338e62a8` | drm/msm Adreno 680 zap shader (`gpu_zap_shader` firmware-name) | Older 26.18.1040.0 copy in `qcdx8180.inf_arm64_a6eeb0588aa111aa` (`f70ddd04…44b62`). Differs from the SQ2 repo copy. |
| `<B>/wlanmdsp.mbn` | `qcwlan8180.inf_arm64_5d147a8cec7f7243\wlanmdsp.mbn` (1.0.2020.0) | 4317112 | `be774cfa5f0cdbdc333819186a162685cc7c63e7823e9e8ca25594974c121887` | WCN3990 Wi-Fi firmware, requested by the MPSS over tqftpserv | tqftpserv must be able to find it; check the path it searches for sc8180x. |
| `ath10k/WCN3990/hw1.0/board-2.bin` | **built** from `qcwlan8180…\bdwlan.*` (staged to `firmware/_staging/ath10k-boards/`) | n/a | n/a | ath10k_snoc | Encode in WSL (see above). Raw hashes: `bdwlan.b58` `a6b1262e…37d7a6e`, `bdwlan.bin` `902d380c…24fe8fd9`. |
| `qca/crbtfw21.tlv` | `qcbtfmuart8180.inf_arm64_83a2b01d61337187\crbtfw21.tlv` (1.0.2020.0, in use) | 230252 | `b393b6377bd86c5834c59681a4143f8c9954198911d6665448006f18a3d64fe1` | hci_uart / btqca (WCN3990) | Same as linux-surface. Older 2019 package `…96d9d71023361ae6` ignored. |
| `qca/crnv21.bin` | same package `\crnv21.bin` | 4710 | `b803e66675b06e4a18ffa0c41611e4792ee62c362e6d12f23610e53b2b9be08a` | btqca NVM (default) | Same as linux-surface. |
| `qca/crnv21.b3c`, `.b45` | same package | 4746 | `2fc8074088c2b6961de126db6a8585fdb2174ca2fffee2de140ea71bdb3452a1` | btqca NVM by board id | `.b3c` and `.b45` are identical. |
| `qca/crnv21.b44`, `.b46`, `.b47`, `.b71` | same package | 4814 | `cef4a0ccffdbd5612a82cf99bc0124b6f4e8bd9f390051acd54fbb104a94c964` | btqca NVM by board id | All four are identical. |
| `qcom/a630_sqe.fw`, `qcom/a640_gmu.bin` | **not in Windows**: linux-firmware | n/a | n/a | drm/msm a6xx | linux-surface ships `a680_sqe.fw`/`a680_gmu.bin` names for its fork; mainline uses the a630/a640 names. |
| `ath10k/WCN3990/hw1.0/firmware-5.bin` | **not in Windows**: linux-firmware | n/a | n/a | ath10k_snoc | See the feature-flag note above. |

### Optional / future (copied only with `-IncludeOptional`)

| Linux path | Windows source | Size | SHA256 | Needed by | Notes |
|---|---|---|---|---|---|
| `<B>/qcvss8180.mbn` (+ `qcom/venus-5.2/venus.mbn`) | `qcdx8180.inf_arm64_9b83a2ef84864dd7\qcvss8180.mbn` | 1142816 | `891997ec156db83ca660359a30a7c139a923d9b9783ead523051816303614a68` | venus (video codec) | Copied by default (cheap). sc8180x venus is not upstream. |
| `<B>/qcslpi8180.mbn` | `surfaceprox_subextscss.inf_arm64_d27055759653cb32\qcslpi8180.mbn` (1.0.710.2) | 6832436 | `7964ffba743cc6c1042faa21ae016c492a733f4de031a087ba2796b1ed354d50` | SLPI sensor DSP (accel/gyro/mag/ALS) | Mainline sc8180x.dtsi has no SLPI remoteproc yet. |
| `<B>/ipa_fws.mbn` | `qcipa8180.inf_arm64_2a97608c0bc6e9f9\ipa_fws.elf` | 37184 | `510f10022640b99042a05aac6ead42435deb4d4e509ec8f4a78b851b4f911b18` | IPA (modem data path) | ELF32. sc8180x IPA is not supported upstream; the name is a guess. |
| `<B>/qdsp6m.qdb` | `surfaceprox_subextmpss…\qdsp6m.qdb` | 5356498 | `4723a56f5e5d399ed7f0b762617f3d8b9bcfad609e4cc6e2d11785ca4bfd3c93` | modem debug DB (diag only) | Same as SQ2. |
| `<B>/modem_pr/mcfg/...` | `surfaceprox_mcfg.inf_arm64_6115a82c0501eae4\MCFG\MCFG.1..28` | various | not hashed | MPSS (full modem) carrier/HW configs via tqftpserv | Staged raw. Rename per the 28-entry table in linux-surface `getfw.py` (e.g. `MCFG.1` → `modem_pr/mcfg/configs/mcfg_sw/oem_sw.txt`, `MCFG.28` → `…/Microsoft/Cambria/hw/rel/sc8180x.gen.prod/common/mcfg_hw.mbn`). |
| `<B>/qcwdsp8180.mbn` | `surfaceprox_auddevext.inf_arm64_5c125d8fec0a8f10\qcwdsp8180.mbn` | 2141415 | `9f23485cd116493001c5c3f17f510a4ccc576f4ecb81b37d4a49ac6ba63327c5` | WCD934x codec DSP (voice wakeup) | Probably never needed. |
| `<B>/CAMERA_ICP_AAAAAA.elf` | `qccamisp8180.inf_arm64_17181fe0285bd6f3\CAMERA_ICP_AAAAAA.elf` | 3597528 | `2a1ca04a13ff358cb9fbc73c273993979b9309d58b7a99f3f87084a07ff05709` | camss ICP (Spectra 390) | No upstream user. Sensor tuning `.bin`s (ov5693/ov13858/ov7251) are Windows CamX only. |
| `_staging/acdb/*.acdb`, `workspaceFile.qwsp` | `surfaceprox_acsp.inf_arm64_4012660cd77ed4b9\` | 9–351 KB | not hashed | reference only | Linux q6asm/AudioReach needs an ALSA topology (`*-tplg.bin`) + UCM. Nothing in Windows maps 1:1; it has to be authored. |

### Found and deliberately ignored
- `surfaceprox_tree…\hdcp1.mbn, hdcp2p2.mbn, hdcpsrm.mbn, storsec.mbn, pr_3_wp.mbn (ELF64)`: TrustZone apps (HDCP, secure storage, PlayReady). Linux doesn't load them.
- `SurfaceTouchFw_4.0.200.139.bin`, SAM, TCON, PD, UEFI, Pen, Type Cover and Dock `*.payload.bin`: Windows firmware-update payloads (CFU), already flashed on the device. Linux needs none of them for touch/SAM to work.
- `qcremotefs8180…\bootmodem_fs1/fs2` (2 MiB each): default modem EFS images. rmtfs uses the device's own EFS partitions. **Never write those partitions** (see PLAN.md rules).
- Hexagon userspace libs (`ADSP\*.so`, `CDSP\*.so`, `fastrpc_shell_*`): only for fastrpc userspace later on.
- `qcsmmu8180\SMMC.bin`, `RCDS.bin`, `SPMD.bin`, sensors JSON: Windows driver config.
- `.jsn` pd-maps: not in Windows (linux-surface hand-wrote them). Not needed with the in-kernel `qcom_pd_mapper` (has sc8180x).
- No `.mdt`/`.bNN` PIL split images, `.b00`, or `.jsn` files exist anywhere in the DriverStore.

## Open questions
1. **Board dir name.** Mainline convention is `qcom/<soc>/<DMI vendor>/<product>/`, e.g. `qcom/sc8180x/LENOVO/82AK`,
   `qcom/sc8280xp/MICROSOFT/SurfacePro9`. The script defaults to `qcom/sc8180x/MICROSOFT/SurfaceProX`; linux-surface used
   `qcom/msft/surface/pro-x-sq2`. The DTS agent and the owner should pick one (SQ1 and SQ2 are separate DTS files, so they need separate dirs) and pass `-BoardDir`.
2. **Wi-Fi board-id/variant.** Which `bdwlan.bXX` matches SQ1? It needs the ath10k QMI board-id from the first boot log. linux-surface used `b58` with board-id `ff` on the SQ2.
3. **`qcmpss8180.mbn` or `_nm`.** `_nm` gives Wi-Fi without the LTE stack and is simpler for M2. Is LTE fitted on this unit? The Windows device list shows "Snapdragon X24 LTE Modem", so yes.
4. **tqftpserv search path** for `wlanmdsp.mbn` and `modem_pr/` on sc8180x: does it follow the remoteproc firmware-name dir?
5. **Re-check SHA256 after Windows Update.** The script warns on change but still copies.
6. **Which ADSP build to use.** The ADSP blob here (1.0.1980.1, 2023) is newer than the linux-surface one. Both should work; watch the battery/pmic_glink behaviour.
