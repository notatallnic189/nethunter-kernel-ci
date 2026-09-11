# nethunter-kernel-ci

[![Kernel build](https://github.com/notatallnic189/nethunter-kernel-ci/actions/workflows/kernel.yml/badge.svg?branch=main)](https://github.com/notatallnic189/nethunter-kernel-ci/actions/workflows/kernel.yml)

A batteries-included GitHub Actions template that builds **Kali NetHunter
kernels** and **signed out-of-tree modules** for Android devices, packages
them with AnyKernel3, and publishes sha256-verified releases. No local build
environment, no docker images, no self-hosted runners.

**Proven on:** Redmi Note 5 Pro (whyred), kernel 4.4.302, sdm660, LineageOS
18.1. The `devices/whyred-los18.1` directory is the live reference: the
released flashable zips are built from exactly the files in it.

## Why this exists

The Kali NetHunter team maintains [official kernel build
scripts](https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-project)
and an [official kernels
listing](https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-kernels)
(rendered at nethunter.kali.org, which lists the whyred kernel from this
template family). This template complements them with the four things that
are usually left to hand-rolling:

1. **Signed modules.** Kernels built with `CONFIG_MODULE_SIG_FORCE=y` reject
   unsigned modules at insmod time, and nothing in the flashable-zip path
   ever signs them. Here every module is signed with the kernel build key in
   the same run and the signature is verified before packaging. Full story in
   [docs/SIGNING.md](docs/SIGNING.md).
2. **Out-of-tree module catalog.** rtl8812au (monitor mode over USB OTG) and
   wireguard-linux-compat build against your kernel automatically, with a
   small env file per module.
3. **Releases, not just artifacts.** Every `v*` tag publishes a flashable zip
   plus sha256 to GitHub Releases, permanently downloadable.
4. **Device config as a directory.** Adding a device means adding
   `devices/<name>/` with an env file, a defconfig and optional patches. No
   script edits, see [docs/ADD-A-DEVICE.md](docs/ADD-A-DEVICE.md).

## Layout

    build.sh                    entry point: ./build.sh <device>
    lib/
      kernel-build.sh           clone + patch + build the kernel image
      build-module.sh           clone + patch + build + sign one module
      sign-module.sh            sign-file + "Module signature appended" check
      package-ak3.sh            AnyKernel3 zip + sha256
    devices/<name>/             one directory per device
      device.env                kernel repo, branch, defconfig, image, modules
      defconfig                 copied into arch/<arch>/configs/
      patches/kernel/           applied to the kernel tree
      patches/driver/           <module>-*.patch applied inside that module
      anykernel.sh              AK3 flash script (partition table)
    modules/<name>.env          one file per out-of-tree module
    .github/workflows/
      kernel.yml                matrix over devices/, release on v* tags
      module.yml                the modkit: one signed .ko against any kernel

## Quickstart

**Use it as-is:** fork or use this template, edit
`devices/whyred-los18.1/device.env` (or add your own directory), then run the
`Kernel build` workflow from the Actions tab, or push a `v*` tag for a full
release with zip + sha256 attached.

**Call it from your own repo:** `kernel.yml` and `module.yml` are
`workflow_call` reusable workflows:

```yaml
jobs:
  kernel:
    uses: notatallnic189/nethunter-kernel-ci/.github/workflows/kernel.yml@main
    with:
      device: whyred-los18.1
```

```yaml
jobs:
  module:
    uses: notatallnic189/nethunter-kernel-ci/.github/workflows/module.yml@main
    with:
      kernel_repo: https://github.com/LineageOS/android_kernel_xiaomi_sdm660.git
      kernel_branch: lineage-18.1
      defconfig_file: devices/whyred-los18.1/defconfig
      module: rtl8812au
```

**Run it locally:** `./build.sh whyred-los18.1` on any x86_64 Linux with
`bc flex bison libssl-dev zip` installed. Everything else is cloned fresh
into the working directory.

## Modules shipped

| Module | Source | What it gives you | Style |
|---|---|---|---|
| rtl8812au | aircrack-ng/rtl8812au | monitor mode + injection on external RTL8812AU class USB adapters | dir |
| wireguard | WireGuard/wireguard-linux-compat | WireGuard VPN on kernels without in-tree support (3.10 to 5.5) | ksrc |

Both are signed in the same run as the kernel they load into. The whyred
device additionally carries the `CONFIG_KERNEL_HAS_NEW_BANDS` rtl8812au patch
as a worked example of per-device module fixes.

## Honest limits

- Proven end to end on one SoC generation: 4.4 / sdm660. Other kernel
  versions may need toolchain or patch adjustments; [docs/ADD-A-DEVICE.md](docs/ADD-A-DEVICE.md)
  lists the three known friction points.
- The modkit always builds the kernel first. That is deliberate:
  `CONFIG_MODVERSIONS=y` kernels need the build's `Module.symvers`, and the
  signing key only exists inside that build, see [docs/SIGNING.md](docs/SIGNING.md).
- Internal WiFi chips on modern SoCs cannot do monitor mode (firmware
  limitation). External adapters over USB OTG are the way, which is why
  rtl8812au ships here.
- Not affiliated with Offensive Security or the Kali NetHunter project. All
  their tooling is linked above and worth reading.

## Docs

- [docs/SIGNING.md](docs/SIGNING.md): why `Key was rejected by service`
  happens and how this template avoids it
- [docs/ADD-A-DEVICE.md](docs/ADD-A-DEVICE.md): the three-variable device guide
- [docs/FAQ.md](docs/FAQ.md): device support, official builder comparison,
  verification, runner details

## Related

- [whyred-nethunter-kernel](https://github.com/notatallnic189/whyred-nethunter-kernel):
  the proven whyred NetHunter kernel built from this template family, with
  release zips and flash guide
- [Kali NetHunter kernel build scripts](https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-project)
  and [official kernels listing](https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-kernels)

## License

GPL-2.0, same as the kernel this template builds. See [LICENSE](LICENSE).
