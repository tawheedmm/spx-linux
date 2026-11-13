# packaging/: turning the SQ1 bring-up into packages and an installer

Design and phases: [../docs/ROADMAP.md](../docs/ROADMAP.md). The kernel workflow lives in
[../.github/workflows/kernel.yml](../.github/workflows/kernel.yml); publishing needs the
maintainer's approval through the `apt-publish` environment.

## Layout (planned; ✅ = exists as a draft)

```
packaging/
  README.md                  ✅ this file
  workflows/
    kernel.yml               ✅ build kernel .debs on arm64 runners; gated publish to the apt repo
    spx-setup.yml               build the arch-all spx-* packages
    iptsd.yml                   build an arm64 iptsd .deb from an upstream tag
    installer-image.yml         mmdebstrap + mkfs -d → USB image on a Release
    apt-repo.yml                (maybe folded into kernel.yml) rebuild + sign + deploy Pages
  kernel/
    base.env                    BASE_REPO / BASE_REF pin (inline in kernel.yml for now)
    rust-toolchain.toml         pinned rustc (≥ 1.85) for the binder Rust code
    meta/                       control templates for linux-image-spx / linux-headers-spx
  spx-setup/
    debian/                     one source package → spx-archive-keyring, spx-firmware-extract,
                                spx-system, spx-boot, spx-audio, spx-setup (meta), spx-widevine
    firmware/map.tsv            DriverStore package/file → /lib/firmware path + known SHA-256
    bin/spx-extract-firmware
    bin/spx-boot
    etc/…                       rmtfs drop-in, initramfs conf.d, modules-load.d, apt pins, .link
  installer/
    build-image.sh              CI version of scripts/build-usb-image.sh (no owner key, no blobs)
    spx-install                 whiptail installer
  export-public.sh              copy the allowlist into the public repo + run the deny check
  public-allowlist.txt
```

## Kernel packages (first deliverable)

`workflows/kernel.yml` does:

1. Fetches Val Packett's `linux-qclaptops` at the pinned commit (`uwu-next` @ `7d84f0635`).
2. `git am kernel-patches/spi-hid-v7/*.patch kernel-patches/audio-wip/*.patch`.
3. Merges `defconfig` + `scripts/spx-cambria.config` + `scripts/spx-camera.config` and fails if a
   fragment option didn't survive.
4. Installs Rust (rustc ≥ 1.85 + `rust-src`, bindgen-cli 0.71) and checks `make rustavailable`
   and `CONFIG_RUST=y`.
5. `make bindeb-pkg` with the uncompressed `Image` (GRUB on arm64 can't load `Image.gz`), then
   checks that `/boot/vmlinuz-*` in the deb starts with `MZ`.
6. Builds the `linux-image-spx` / `linux-headers-spx` metapackages.
7. Uploads the debs, `.config` and a source tarball as artifacts.
8. **publish** job (only on manual dispatch, behind the `apt-publish` environment, which needs the
   owner's approval): attaches everything to a GitHub Release, rebuilds the apt repo from the
   last releases, signs it, and deploys it to GitHub Pages.

### Secrets / settings the public repo will need (owner creates them; none exist yet)
| Name | What |
|---|---|
| `APT_SIGNING_KEY` | ASCII-armoured private **signing subkey** only (`gpg --export-secret-subkeys --armor <fpr>!`) |
| `APT_SIGNING_KEY_ID` | its fingerprint |
| `APT_SIGNING_PASSPHRASE` | passphrase of that subkey (the primary key stays offline with the owner) |
| environment `apt-publish` | required reviewer: the owner. Protects the three secrets above |
| Pages | source = "GitHub Actions" |

### Testing it locally before any push
The workflow steps are plain shell. To dry-run the build on the WSL host (native arm64):
copy the `run:` blocks of the `build` job into a script, set `PROJ` to this repo, and run it in a
`ubuntu:26.04` container (or the `builder` user's tree). Expect 1.5–2.5 h with the full defconfig.

## User-facing install (what the README of the public repo would say, once phase 1 ships)

```
# one-time: add the repo (keyring package downloaded from the Releases page, checksum shown there)
sudo apt install ./spx-archive-keyring_*.deb
sudo apt update
sudo apt install linux-image-spx
# later phases:
sudo apt install spx-setup          # firmware extraction, rmtfs, initramfs, audio, touch
sudo spx-extract-firmware           # reads your own Windows partition, read-only
sudo spx-boot install               # explicit: writes \EFI\spx + one boot entry, asks first
```

## Contributing
See [../CONTRIBUTING.md](../CONTRIBUTING.md): no firmware or personal data, never touch the
boot setup without asking, keep patch authorship intact.
