# Roadmap

Goal: a Surface Pro X SQ1 owner gets a working Linux desktop without having to research
anything, and this repo shrinks as the pieces land upstream.

| Phase | Ships | State |
|---|---|---|
| 0 | This public repo: patches, configs, setup files, docs | in progress |
| 1 | **Kernel packages**: `linux-image-spx` / `linux-headers-spx`, built by GitHub Actions on arm64 runners, served as a signed apt repo on GitHub Pages (`testing` and `stable` suites), with the corresponding GPL source attached to every release. Kernel updates arrive via `apt upgrade` | CI workflow drafted ([.github/workflows/kernel.yml](.github/workflows/kernel.yml)) |
| 2 | **`spx-setup` packages**: firmware extraction from your own Windows partition (read-only), file-backed rmtfs for the modem, initramfs and module settings, apt pins, touch daemon, and (opt-in, on explicit command only) the boot entry on the ESP. Audio once its licensing is settled | designed |
| 3 | **USB installer** (8 GB stick): boots, extracts firmware, brings up Wi-Fi, installs Ubuntu + GNOME into free NVMe space next to Windows. You shrink Windows yourself first; the installer never resizes NTFS | designed |
| 4 | **Shrink**: drop each piece as it lands upstream (mainline kernel, linux-surface, alsa-ucm-conf, iptsd) | ongoing |

## Ground rules
- No Windows firmware, Widevine or personal data in any package, image or CI artifact.
- Package install scripts never touch the ESP or UEFI boot entries. Only an explicit
  `spx-boot install` does that, after asking.
- Supported: SQ1 LTE ("cambria"). SQ1 Wi-Fi-only: allowed, marked untested. SQ2: out of scope
  (see linux-surface).
