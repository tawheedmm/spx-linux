# kernel-patches/spx: the Surface Pro X (SQ1) kernel series

Base: https://github.com/valpackett/linux-qclaptops branch `uwu-next` @ 7d84f0635
(7.4.0-rc2-next-20261109). Apply in order:

    git clone --depth 30 -b uwu-next https://github.com/valpackett/linux-qclaptops.git linux
    cd linux && git checkout 7d84f0635
    git am ../kernel-patches/spx/*.patch
    # config: arm64 defconfig + scripts/spx-cambria.config + spx-camera.config + spx-perf.config
    # (see scripts/build-kernel.sh and .github/workflows/kernel.yml)

| Patches | What |
|---|---|
| 0001 | cambria DTS fixes: QUP0/QUP2, lid switch, NVMe 3.3 V |
| 0002–0013 | upstream spi-hid v7 (HID over SPI), replacing the old out-of-tree copy |
| 0014–0017 | Surface Pro X digitizer: pre-release protocol support, compatible, DTS |
| 0018 | panel-edp: LGD LP129WT112684 (merged upstream in drm-misc-next) |
| 0019–0037 | cameras: CAMSS/CCI for sc8180x, front (OV5693) and IR (OV7251) cameras, IR emitter; patches marked WIP are not upstream quality yet |
| 0038 | PCI: qcom: don't advertise hot-plug without the global interrupt |
| 0039–0040 | spi-hid: reliable digitizer reset at boot (300 ms power-on delay, reset retry) |
| 0041 | build fix: drop test-variant DTB entries |

Not included yet: audio (speakers and microphones work, but the device tree is derived from
another contributor's patches and waits for their agreement on credit).
