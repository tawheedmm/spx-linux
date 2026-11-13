# Kernel patches (our work on top of Val Packett's uwu-next)

Base: https://github.com/valpackett/linux-qclaptops branch `uwu-next` @ 7d84f0635
(7.4.0-rc2-next-20261109). To rebuild elsewhere:

    git clone --depth 30 -b uwu-next https://github.com/valpackett/linux-qclaptops.git linux
    cd linux && git checkout 7d84f0635
    git am ../kernel-patches/spi-hid-v7/*.patch          # cambria DTS, spi-hid v7 + Pro X, panel
    # config: merge ../scripts/spx-cambria.config onto arm64 defconfig (see scripts/build-kernel.sh)
