# Contributing

Thanks for helping. Test reports from other Surface Pro X owners are as valuable as code. Please
open an issue with your model (SQ1 LTE, SQ1 Wi-Fi, SQ2), what you tried and what happened.

A few rules keep this project safe to use and legal to distribute. Pull requests that break them
can't be merged.

## 1. No firmware or personal data, anywhere
Never add any of the following to the repository, a package, an image, a CI artifact or a CI log:
- firmware extracted from Windows (`.mbn`, `.elf`, board files, and so on). It isn't
  redistributable; each owner extracts their own (see `scripts/extract-firmware.ps1`)
- Widevine or other proprietary binaries
- anything that identifies a specific machine or person: serial numbers (the ACPI `SOSN` value,
  the panel serial inside a raw EDID), Windows product keys (MSDM), MAC addresses, IP addresses,
  Wi-Fi names or passwords, SSH keys, e-mail addresses other than in patch trailers

CI builds run on public infrastructure. Their artifacts and logs are public. When you attach logs
to an issue, remove these values first.

## 2. Never touch the boot setup without asking
The EFI system partition is shared with Windows. Package install and upgrade scripts must not
write to the ESP or change UEFI boot entries. Only an explicit, interactive command (the planned
`spx-boot install`) may do that, and only after showing the user what it will change.

## 3. Keep patch authorship intact
Kernel patches carry their authors' `Signed-off-by` (the
[Developer Certificate of Origin](https://developercertificate.org/)). Only the author can add
theirs. Apply patches with `git am` and never re-author them. If you adapt someone else's patch,
credit them (`Co-developed-by:` with their sign-off, or "Based on a patch by …" plus a link).

## 4. Prefer upstream
This repo is an interim layer. If a fix belongs in the kernel, linux-surface, alsa-ucm-conf or
iptsd, send it there too, and link the upstream submission in your pull request.

## Licences
By contributing you agree that your contribution is licensed like the files it touches: MIT for
scripts, docs and packaging, GPL-2.0 for kernel patches and config fragments (see `LICENSES.md`).
