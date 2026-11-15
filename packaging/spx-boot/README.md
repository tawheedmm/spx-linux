# spx-boot

Boot setup for Linux on the Surface Pro X (SQ1). Kernels stay on the Linux root filesystem
(`/boot`). Only a small standalone GRUB (`grubaa64.efi`, ~3 MB) and a generated `grub.cfg` go to
`\EFI\spx` on the EFI system partition shared with Windows.

```
sudo apt install spx-boot linux-image-spx
sudo spx-boot install --dry-run     # shows the plan and the generated menu, changes nothing
sudo spx-boot install               # asks "Type YES" before writing anything
```

After `install`, every kernel install or removal updates the menu automatically
(`/etc/kernel/postinst.d/zz-spx-boot`, `postrm.d/zz-spx-boot`).

## Menu
- **SPX Linux**: the newest kernel (default)
- **SPX Linux (previous kernel …)**: the one before it (`SPX_KEEP=2`)
- **safe mode**: newest kernel without GPU, touch, Type Cover and DSP drivers
- **Windows**, **UEFI firmware settings**

The one-shot boot block (`next_entry` in `\EFI\spx\grubenv`) is included, so a tool like
`spx-boot-once` can boot an entry once.

Kernels are listed only if they have an uncompressed EFI `Image` (`/boot/vmlinuz-*` starting with
`MZ`), an initrd, and the device tree at `/usr/lib/linux-image-<release>/qcom/`. The
`linux-image-spx` packages meet all three.

## Safety rules
- Package install and upgrade scripts never call `spx-boot install`. Before you run it, nothing
  on the ESP or in UEFI variables changes, and the kernel hooks do nothing.
- `install` touches only `\EFI\spx`. It never touches `\EFI\Microsoft` or other files.
- It backs up the UEFI boot variables to `/var/lib/spx-boot/` and adds **one** UEFI entry
  "SPX Linux" (none if an entry for `\EFI\spx\grubaa64.efi` already exists). The boot order stays
  as it is unless you pass `--make-default`.
- It refuses to overwrite a hand-made `\EFI\spx\grub.cfg` unless you pass `--adopt`, which backs
  it up to `\EFI\spx\backup-before-spx-boot/` first. Adopting changes your default boot entry.
- Every `update` keeps the previous menu as `grub.cfg.prev` and replaces the file atomically.

## Machines set up by hand
If your system has an initramfs hook that copies new initrds to the ESP (for example
`/etc/initramfs/post-update.d/zz-spx-esp` from the early bring-up), remove it before
`spx-boot install --adopt`. Otherwise every initramfs update overwrites the ESP copy your old
menu used.

## Settings
`/etc/default/spx-boot`: timeout, number of kernels, kernel command line additions
(`SPX_CMDLINE_EXTRA`), device tree override, safe-mode entry. Run `sudo spx-boot update` after
changing it.

## Development
- `test-spx-boot.sh`: sandbox test (fake /boot, device tree and ESP; never touches the real ESP or
  UEFI). 25 checks.
- `build-deb.sh`: builds `spx-boot_<ver>_arm64.deb`. Needs `grub-efi-arm64-bin` for
  `grub-mkstandalone`; the GRUB version used is recorded in `/usr/share/doc/spx-boot/GRUB-SOURCE`.

Licence: MIT (scripts). The bundled GRUB image is GPL-3.0-or-later.
