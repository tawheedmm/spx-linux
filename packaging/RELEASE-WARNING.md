⚠️ **Experimental: for testers who already run Linux on a Surface Pro X SQ1.**

These packages install the kernel, its modules and the device tree only. They do **not** set up booting yet: nothing adds the kernel to your GRUB menu on the EFI partition (that will be the spx-setup / spx-boot package). Before installing:

- Know how your machine boots and keep a working entry and a rescue USB stick.
- If an initramfs hook on your system copies new initrds to the EFI partition, installing can make your default entry pair the old kernel with the new initrd. Check `/etc/initramfs/post-update.d/` first.
- Audio is not included yet (pending licensing).

Tested: boots on SQ1 LTE (cambria) with display, GPU, touch, Wi-Fi, Bluetooth, Type Cover and all DSPs including the modem. Not tested on SQ1 Wi-Fi-only or SQ2.
