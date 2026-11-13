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
