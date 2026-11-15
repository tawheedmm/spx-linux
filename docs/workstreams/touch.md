# Touch and pen (HID over SPI + iptsd): 2026-11-12

Digitizer: Microsoft 045E:0996 on SPI1 (QUP0, 0x884000), IRQ tlmm 122 (edge), HID-over-SPI driver
`drivers/hid/spi-hid` from Val's uwu-next (the upstream v7 series). Userspace: linux-surface/iptsd
(built from source, `scripts/build-iptsd.sh`).

## Result
| Mode | Status | Evidence |
|---|---|---|
| Basic HID (single touch) | **works** out of the box | `logs/touch-test-1.txt`: BTN_TOUCH + ABS_X/Y 0–32767 |
| iptsd multitouch | **works** with the workaround below | `logs/touch-test-4.txt`: 7,926 MT events, 6 slots, 7 distinct contacts, orientation + touch-major, 3.2 MB raw data, no driver errors |
| Pen | device declared (pressure, tilt, eraser, side button); **untested, no pen available** | `IPTSD Virtual Stylus` created |

The HID descriptor (4096 bytes, length matches wReportDescLength) has no Contact Identifier/Contact
Count usages: native multitouch isn't offered, and the raw IPTS data sits in vendor pages (0xFF00…).

Kernel config needed: `CONFIG_HIDRAW=y`, `CONFIG_INPUT_UINPUT=y` (now in `scripts/spx-cambria.config`).

## Bug 1: spi-hid open/ready race (blocks iptsd)
`spi_hid_ll_open()` asserts reset, enables the IRQ, powers up, deasserts reset and **returns
immediately**. `shid->ready` is only set later, when the device's reset response arrives by
interrupt. Any `HIDIOCGFEATURE` issued right after `open()` hits `spi_hid_ll_raw_request()` while
`!shid->ready` and fails with `-ENODEV` ("raw_request called in unready state").

- iptsd opens `/dev/hidraw0` and immediately sends `HIDIOCGFEATURE(120)` (ioctl 0xC0784807), so it
  fails with "IOCTL … failed: No such device", `iptsd-check-device` rejects the device, and iptsd's udev
  rule never starts the service.
- Reads during the power-up window return `00 00 00 00` / `ff ff ff ff` headers ("Invalid input report
  sync constant"), which is the same root cause seen from the IRQ side.
- `evtest` "works" only because it waits passively until the device is ready.

**Proposed fix (upstream):** make `ll_open` (or `raw_request`) wait for the reset response with a
timeout, as i2c-hid does in `i2c_hid_hwreset()` (`wait_event_timeout` on a reset-complete flag
set from the reset-response path), and/or have `raw_request` wait on `ready` instead of failing.

**Workaround in this repo:** `boot/spx-touch-hold.service` holds `/dev/hidraw0` open so the device stays
in D0, then starts `iptsd@dev-hidraw0.service`. `boot/60-spx-touch.rules` tags 045E:0996 for systemd,
because iptsd's rule skips the device when its probe hits the race.

## Bug 2: IRQF_ONESHOT without a thread handler
`spi_hid_probe()`: `request_irq(spi->irq, spi_hid_dev_irq, irq_get_trigger_type(...) | IRQF_ONESHOT, ...)`
triggers `WARN_ON_ONCE(new->flags & IRQF_ONESHOT && !new->thread_fn)` in `__setup_irq`
(kernel/irq/manage.c). Either drop IRQF_ONESHOT or move the SPI transfer into a threaded handler
(`request_threaded_irq(irq, NULL, handler, ...)`). The latter is better, since the handler does SPI I/O
under a spinlock in hard-IRQ context today.

## Other notes
- `surface_hid 01:15:02:02`: "unexpected descriptor length: got 0, expected 9" (probe -71); a SAM HID
  sub-device, not the digitizer. To investigate.
- No pen available for testing; ask a community member with an SQ1 and a Surface Pen to test.

## Bug 3: digitizer silent at boot in about 1 boot in 7 (2026-11-14, root cause found and fixed)
**In the default kernel since 2026-11-15** (owner's approval): `-touch-g9ac4e4e7b057`, WSL branch
`touch-reset` (perf-wip + the two commits below), fragments spx-camera.config + spx-perf.config, same
command line (with `ssbd=force-on`). Promoted with scripts/dut-promote-default-kernel.sh; previous
kernel = `-perf-gee7989b5872d`, older = `-spxcam-gee7989b5872d` in /boot/older. First boot: digitizer
up at 5.9 s without help. `spx-touch-check.service` stays enabled for a few days as a safety net
(owner's choice); disable it if `journalctl -u spx-touch-check` never shows a rebind.

Symptom: spi-hid binds, but no HID device appears; `spx-touch-check.service` (boot/touch-watchdog/)
rebinds the driver 20 s after boot. The journal showed this in 10 of 75 boots since the watchdog was
installed (13 %), on every kernel.

**Root cause: reset is released too soon after power on.** The digitizer runs from `vreg_ts_5p0`, a
5 V rail switched by PMC8180 GPIO 10, and that rail is always off when the driver probes (it is
off in all 130 instrumented boots). `spi_hid_dev_init()` asserts reset, waits 100 ms, enables the
rail, waits `post_power_on_delay_ms` (10 ms, copied from the g6 data) and releases reset. In the
failing boots the digitizer never answers: an instrumented kernel (WSL branch `touch-reset-dbg`,
sampling the INT line every 100–150 µs for 800 ms after reset release) shows **no INT edge at all**
and 0 interrupts even at 30 s. So the interrupt isn't lost: the device misses the reset. In good
boots INT falls 135.4–135.6 ms after reset release (reset response), in every boot.

Windows waits longer: the ACPI `_PS0` of `\_SB.GTCH` (MSHW0134; hw/acpi/DSDT.dsl, around line
102306) sleeps **300 ms**, then sets TLMM GPIO 54 high (writes 2 to 0x03136004, i.e. releases the
active-low reset), then sleeps 150 ms.

Evidence (boots of a non-default test entry with the watchdog masked; logs in logs/touch-reset/):

| Kernel | Boots | Digitizer missing |
|---|---|---|
| perf kernel + instrumentation, 10 ms after power on (as today) | 25 | **4** |
| same kernel, `spi_hid_of.dbg_post_power_ms=300` | 40 | **0** |
| retry patch only, 10 ms (instrumented) | 25 | 0 missing; the first reset was missed in **10** boots and one more reset (power kept on) brought the device up each time |
| **final: perf-wip + retry patch + 300 ms** (`-touch-g9ac4e4e7b057`) | 40 | **0**, and the retry never fired |

Also checked with the final kernel: two s2idle cycles, touch back after each (the
`Unknown input report version (v 0x0)` at resume was already there on the default kernel and is
harmless: a garbage edge while the device powers up, dropped while the reset is pending).

**Fix** (WSL branch `touch-reset` on `perf-wip`):
1. `HID: spi-hid-of: wait 300 ms after power on for the Surface Pro X digitizer`: the Pro X match
   data gets `post_power_on_delay_ms = 300`, the ACPI value. This fixes the root cause. It also
   applies on resume when the digitizer was powered off (about 290 ms longer, like Windows' `_PS0`).
2. `HID: spi-hid: retry the reset when the device does not answer it`: a delayed work armed after
   each reset (probe, error recovery, resume) goes through the error handler if no reset response
   arrived within `SPI_HID_RESET_TIMEOUT` (1 s). Generic robustness: before it, a missed reset left
   the driver bound but deviceless until someone rebound it.
Upstream draft: docs/upstream/rfc-spi-hid-prox/v2-touch-reset/ (not sent).
Tools: scripts/dut-install-touch-entry.sh (test entry "SPX Linux (test: touch)", files in
/boot/touch-test/), scripts/touch-bootloop.sh (N one-shot boots, records touch OK/MISSING).

Once a kernel with both patches is the default, `spx-touch-check.service` can be disabled (the owner
decides that).
