# Adding a device

The whole point of this template: adding a device means adding a directory,
not editing scripts. This guide walks through the three required variables
and the three friction points you are most likely to hit.

## Step 1: copy the reference device

    cp -r devices/whyred-los18.1 devices/<your-device>

The reference device is a complete, proven example: env file, defconfig,
kernel patch, driver patch, AnyKernel3 script. You will keep the shape and
replace the content.

## Step 2: edit device.env (three required variables)

Minimum working edit, three variables:

```sh
KERNEL_REPO="https://github.com/<org>/<android_kernel_your_soc>.git"
KERNEL_BRANCH="<branch>"
ZIP_PREFIX="<yourdevice>-nethunter-kernel"
```

You will most likely also change:

```sh
DEFCONFIG="your-nethunter_defconfig"   # name of the make target
KERNEL_IMAGE="Image.gz-dtb"            # or Image.lz4-dtb / Image.gz / Image
DEVICE_MODULES="rtl8812au wireguard"   # or fewer, or empty
```

Details that matter:

- `DEFCONFIG` is the make target name. The defconfig *file* sits next to
  `device.env` and is copied into `arch/arm64/configs/` before building. If
  your defconfig already exists inside the kernel tree, keep the name and
  delete the local file.
- `DEVICE_MODULES` entries each need a `modules/<name>.env` file. If you
  leave it empty the build skips the module section entirely and packages a
  kernel-only zip.
- `ARMTC_REPO` is optional. Provide it if your kernel needs a real arm32 gcc
  for the vdso build; without it proton-clang's arm-linux-gnueabi- tools are
  used.
- The `*_REF` variables (kernel, toolchains, AnyKernel3, per-module) pin a
  source to an exact commit SHA: set them when you want "same repo state,
  same sources" instead of whatever HEAD happens to be that day. Leave them
  out to track the branch. The reference device ships with pins, recorded
  with the branch each SHA was resolved from.

## Step 3: make the device yours

1. **defconfig**: replace `defconfig` with yours. The whyred one is a
   LineageOS sdm660 defconfig plus NetHunter items (HID gadget, functionfs,
   FW_LOADER_USER_HELPER, no ANDROID_PARANOID_NETWORK, module signing on).
   Search your tree's defconfig for those options to see what a NetHunter
   kernel needs.
2. **anykernel.sh**: edit the `device.name1`, `kernel.string` and the block
   variables. A/B slot devices need `IS_SLOT_DEVICE=1`; devices with dynamic
   partitions may need vbmeta flags. The AnyKernel3 repo docs cover the
   details.
3. **patches** (optional): kernel fixes go in `patches/kernel/*.patch`
   (applied to the kernel tree), module fixes in
   `patches/driver/<module>-*.patch` (applied inside that module's source,
   the leading directory name selects the module). Delete the whyred
   examples you do not need.

## Step 4: build it

Run it from the Actions tab (`Kernel build` workflow, put your device name in
the input) or push a tag for a full release. The first run is the real test:
read the log top to bottom once, it is written to be read.

## The three friction points (expect these)

1. **Toolchain mismatch.** 4.4 and 4.9 trees usually build with proton-clang
   out of the box. 4.14+ trees often need a newer clang or extra
   `-Wno-error` flags; very new trees may need their own toolchain entries.
   The whyred device shows the pattern: a small kernel patch
   (`kernel-vdso32-toolchain-fixes.patch`) to make an old tree cooperate
   with a new compiler.
2. **Image target name.** `Image.gz-dtb` is common on 4.4 sdm660, other SoCs
   want `Image.lz4-dtb`, `Image.gz`, or plain `Image`, and a wrong name fails
   at the packaging step with a clear message. Check what your device's
   existing ROM kernels ship.
3. **AnyKernel3 partition layout.** A/B devices, dynamic partitions and
   vendor_boot kernels need more than the classic `BLOCK=` boot flash. Start
   from an AnyKernel3 script known to work for your device and port the
   variables over.

When your device builds, open a PR with the directory. Every proven device
makes the next one easier, and the matrix workflow will pick it up
automatically on the next tag.
