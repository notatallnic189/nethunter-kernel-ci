# FAQ

Questions that come up around building NetHunter kernels and modules with
GitHub Actions. If your question is not here, open an issue.

## Does this work for my device?

The template is proven on one device end to end: Redmi Note 5 Pro (whyred),
kernel 4.4.302, sdm660, LineageOS 18.1. The whole pipeline (kernel image,
out-of-tree modules built and signed when the tree actually needs them,
AnyKernel3 zip, sha256 release) runs green from this repository. On whyred
that means the signed `88XXau` module plus one deliberate skip: the defconfig
has `CONFIG_WIREGUARD=y`, so WireGuard is inside the kernel image and the
out-of-tree module is not built. Other devices need their own
`devices/<name>` directory and will likely need toolchain or patch
adjustments, see
[ADD-A-DEVICE.md](ADD-A-DEVICE.md) for the three friction points to expect.
This is not a one-size-fits-all builder, it is a template that
removes the boring 80 percent and leaves you the device-specific 20.

## How is this different from the official Kali NetHunter kernel builder?

The Kali team maintains build scripts for NetHunter kernels
(gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-project) and an
official kernels listing (kali-nethunter-kernels, rendered at
nethunter.kali.org, where the whyred kernel from this template family is
listed). Those produce kernel zips. What this template adds on top:

1. module signing with per-build keys so `CONFIG_MODULE_SIG_FORCE=y` kernels
   actually load the modules, see [SIGNING.md](SIGNING.md)
2. out-of-tree modules built against your kernel in the same run (rtl8812au,
   wireguard-linux-compat)
3. sha256 sums next to every release zip
4. device configuration as a directory instead of script edits

Using both is fine: the official builder if you want the classic path, this
template if you want signed modules and CI releases without a local build
environment.

## Can I build rtl8812au for Android kernel 4.4 monitor mode?

Yes, that is exactly what the shipped `modules/rtl8812au.env` plus the whyred
device does. Two device-specific realities to know about: the internal
sdm660 WiFi chip (WCN3980) cannot do monitor mode or injection, you need an
external RTL8812AU class adapter over USB OTG; and on 4.4 kernels that
backported newer cfg80211 symbols the module needs the
`CONFIG_KERNEL_HAS_NEW_BANDS` fix, which the whyred device carries as a
driver patch you can copy.

## Why does building one module take so long in the modkit workflow?

Because the kernel is built first, on purpose. Two reasons:

1. `CONFIG_MODVERSIONS=y` kernels generate symbol version CRCs during the
   kernel build (`Module.symvers`). Without that file, out-of-tree modules
   either fail to link or load with broken symbol versions.
2. The signing key and `sign-file` tool are products of the same kernel
   build. A module signed with a key from another build will not load on a
   SIG_FORCE kernel, see [SIGNING.md](SIGNING.md).

## Where do the flashable zips come from and how do I verify them?

Every `v*` tag triggers a build and attaches the zip plus its `.sha256` to a
GitHub release. Verify before flashing:

    sha256sum -c whyred-nethunter-kernel-YYYYMMDD.zip.sha256

The hash listed matches the zip in the same release. Do not flash zips from
anywhere else.

## Does the zip install Magisk or a recovery?

No. The zip is a plain AnyKernel3 boot image flash: it writes the kernel to
the boot partition and drops the signed modules systemless. You flash it from
an existing recovery or via `adb reboot bootloader` + fastboot boot of a
recovery. Root state is whatever your ROM already has.

## Can I reuse the workflows in my own kernel repo?

Yes. `kernel.yml` is a `workflow_call` reusable workflow: from your repo you
can call it with a `device` input, or just fork this template and add your
device directory. `module.yml` takes a kernel URL, a branch, a defconfig and
a module name, and returns a signed `.ko` artifact. Both run on public
GitHub-hosted runners, no self-hosted anything.

## What kernels does the toolchain support?

The default is proton-clang plus (for devices that need CROSS_COMPILE_ARM32)
a gcc 4.9 arm32 toolchain, which covers the 4.4 to 4.9 era phones NetHunter
usually targets. Newer trees (4.14, 4.19, 5.x) generally want newer clang and
may need the vdso32 or compiler patches adjusted; the whyred device carries
an example of exactly such a patch under
`devices/whyred-los18.1/patches/kernel/`. If your device builds, a PR adding
it under `devices/` is very welcome, it grows the set of proven
configurations for everyone.

## Is any of this affiliated with the Kali NetHunter project?

No. This is an independent community template. The NetHunter names and
project belong to Offensive Security and the Kali team; links to their
repositories are given above for attribution and because you should know
what is official and what is not.
