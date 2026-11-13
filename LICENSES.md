# Licences in this repository

| Path | Licence |
|---|---|
| `kernel-patches/**` | GPL-2.0 (device-tree files: GPL-2.0 OR BSD-2-Clause, as upstream). These are patches to the Linux kernel and carry their authors' `Signed-off-by` |
| `scripts/spx-*.config` | GPL-2.0 (kernel configuration fragments) |
| Everything else (scripts, boot/system files, packaging, CI workflows, docs) | MIT, see [LICENSE](LICENSE) |

## Not in this repository, never redistributed
- **Firmware extracted from Windows** (Qualcomm/Microsoft DSP, GPU zap shader, Wi-Fi and modem
  files). It isn't redistributable. Each owner extracts it from their own Windows installation:
  see [docs/workstreams/firmware.md](docs/workstreams/firmware.md) and
  [scripts/extract-firmware.ps1](scripts/extract-firmware.ps1).
- **Widevine**: proprietary, installed by the user (e.g. with AsahiLinux/widevine-installer)
  after accepting Google's licence.

## Third-party work this builds on
- Kernel base: Val Packett's [linux-qclaptops](https://github.com/valpackett/linux-qclaptops) (`uwu-next`).
- spi-hid v7: Jingyuan Liang et al. (upstream series on linux-input).
- Audio (not included yet): ajacocks' Surface Pro X SQ2 work,
  [linux-surface/surface-pro-x#21](https://github.com/linux-surface/surface-pro-x/issues/21).
- Touch daemon: [linux-surface/iptsd](https://github.com/linux-surface/iptsd) (GPL-2.0-or-later, built from upstream).
