# spx-linux: Linux on the Microsoft Surface Pro X (SQ1)

Kernel patches, configuration and system setup to run a current Linux desktop on the
**Surface Pro X with the SQ1 chip** (Qualcomm sc8180x), tested on the LTE model ("cambria",
SKU 1876) with Ubuntu 26.04 and GNOME.

This is an **interim** layer. It builds on Val Packett's sc8180x kernel tree and is meant to
shrink as the pieces land upstream (mainline Linux, linux-surface, alsa-ucm-conf, iptsd). It
isn't a distribution and doesn't compete with [linux-surface](https://github.com/linux-surface/surface-pro-x).

> **Status: not yet installable for end users.** Kernel packages (an apt repository) come
> first, then a setup package, then a USB installer. See the [roadmap](docs/ROADMAP.md).
> Until then, this repo documents what works and how.

## What works (SQ1 LTE)

| Area | State |
|---|---|
| Boot from internal NVMe next to Windows (standalone GRUB on the ESP) | ✅ |
| Display 2880x1920 + backlight | ✅ (panel-edp entry under review upstream) |
| GPU: OpenGL 4.6, Vulkan 1.3 (freedreno / Turnip) | ✅ |
| NVMe, Type Cover, battery, lid, CPU frequency scaling | ✅ |
| Wi-Fi, Bluetooth | ✅ |
| ADSP, CDSP, SLPI, LTE modem (remoteprocs) | ✅ (modem needs file-backed rmtfs) |
| Multitouch | ✅ (spi-hid v7 + Pro X protocol patch, stock iptsd) |
| Speakers and microphones | ✅ locally. Not in this repo yet (licensing of the audio files is being sorted out) |
| Android apps (Waydroid) | ✅ (needs the Rust binder in the kernel) |
| Suspend | ❌ |
| Cameras | ❌ (in progress) |
| Pen | ❓ untested |

Status report with details: [linux-surface/surface-pro-x#55](https://github.com/linux-surface/surface-pro-x/issues/55).

## Contents

| Path | What |
|---|---|
| [kernel-patches/](kernel-patches/) | Patches on top of Val Packett's `uwu-next` (cambria DTS fixes, spi-hid v7 + Pro X support, panel entry) and how to apply them |
| [scripts/spx-cambria.config](scripts/spx-cambria.config), [spx-camera.config](scripts/spx-camera.config) | Kernel config fragments (merge onto arm64 `defconfig`) |
| [scripts/build-kernel.sh](scripts/build-kernel.sh) | Build the kernel (native arm64). Produces the uncompressed `Image` GRUB needs |
| [scripts/extract-firmware.ps1](scripts/extract-firmware.ps1) | Copy the firmware Linux needs out of **your own** Windows installation |
| [boot/](boot/) | GRUB menu, touch watchdog, Waydroid nftables hook, ALSA modprobe fix, boot-once helpers |
| [docs/](docs/) | Firmware map, touch notes, status, roadmap |
| [.github/workflows/kernel.yml](.github/workflows/kernel.yml) | CI that builds the kernel `.deb`s (publishing requires maintainer approval) |

## Essentials if you're setting this up by hand

- Kernel command line: `efi=novamap clk_ignore_unused pd_ignore_unused deferred_probe_timeout=60`
  (without the timeout, msm gives up on the late eDP PHY and you stay on simpledrm).
- GRUB on arm64 needs the **uncompressed** `Image`, not `Image.gz`.
- initramfs-tools: `MODULES=dep`, so remoteproc and spi-hid don't probe before `/lib/firmware` is reachable.
- Modem: run rmtfs as `rmtfs -r -s -o /var/lib/rmtfs` with blank `modem_fs1`, `modem_fs2`,
  `modem_fsg` (2 MiB) and `modem_fsc` images (Windows-on-ARM laptops have no modemst partitions).
- `snd-soc-sdm845` doesn't autoload: add it to `/etc/modules-load.d/`.
- Firmware goes in `/lib/firmware/qcom/sc8180x/microsoft/cambria/`. GPU microcode
  (`a630_sqe.fw`, `a640_gmu.bin`) comes from linux-firmware.

## Firmware and privacy

No firmware from Windows is included or redistributed here. It isn't ours to share. Each owner
extracts it from their own machine. Never post your raw EDID, ACPI dumps or logs without
removing serial numbers and network identifiers.

## Upstream work

- panel-edp: LGD LP129WT112684 (dri-devel)
- HID: spi-hid support for the Surface Pro X digitizer's pre-release protocol (RFC, linux-input)
- Cambria DTS fixes: [linux-surface/surface-pro-x#53](https://github.com/linux-surface/surface-pro-x/issues/53)
- Modem/rmtfs: [linux-surface/surface-pro-x#54](https://github.com/linux-surface/surface-pro-x/issues/54)
- Firmware script: [linux-surface/aarch64-firmware#5](https://github.com/linux-surface/aarch64-firmware/issues/5)

## Licence

MIT for our scripts and docs, GPL-2.0 for kernel patches and config. See [LICENSES.md](LICENSES.md).

## Contributing

Test reports and fixes are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.
