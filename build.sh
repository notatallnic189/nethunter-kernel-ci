#!/usr/bin/env bash
# nethunter-kernel-ci: build one device end to end.
#
# Usage:  ./build.sh <device>
#         e.g. ./build.sh whyred-los18.1
#
# Reads devices/<device>/device.env, then builds:
#   kernel image + out-of-tree modules (built and signed) + AnyKernel3 zip
#   + sha256. Runs locally or inside .github/workflows/kernel.yml.
#
# Adding a device means adding a directory under devices/, not editing this
# script. See docs/ADD-A-DEVICE.md.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DEVICE="${1:-${DEVICE:-}}"
[ -n "$DEVICE" ] || { echo "usage: $0 <device>   (see devices/)" >&2; exit 1; }
ENVFILE="$ROOT/devices/$DEVICE/device.env"
[ -f "$ENVFILE" ] || { echo "ERROR: unknown device '$DEVICE': $ENVFILE not found" >&2; exit 1; }

echo "[*] device: $DEVICE"
# shellcheck disable=SC1090
source "$ENVFILE"
: "${KERNEL_REPO:?KERNEL_REPO missing in device.env}"
: "${KERNEL_BRANCH:?KERNEL_BRANCH missing in device.env}"
: "${DEFCONFIG:?DEFCONFIG missing in device.env}"
: "${KERNEL_IMAGE:?KERNEL_IMAGE missing in device.env}"
: "${ZIP_PREFIX:?ZIP_PREFIX missing in device.env}"
ARCH="${ARCH:-arm64}"
PROTON_REPO="${PROTON_REPO:-https://github.com/kdrag0n/proton-clang.git}"
ARMTC_REPO="${ARMTC_REPO:-}"
AK3_REPO="${AK3_REPO:-https://github.com/osm0sis/AnyKernel3.git}"
DEVICE_MODULES="${DEVICE_MODULES:-}"
DEFCONFIG_FILE=""   # modkit knob, unused for full device builds

WORKDIR="${GITHUB_WORKSPACE:-$PWD}"
cd "$WORKDIR"
JOBS="$(nproc)"

# shellcheck source=lib/kernel-build.sh
source "$ROOT/lib/kernel-build.sh"
# shellcheck source=lib/build-module.sh
source "$ROOT/lib/build-module.sh"
# shellcheck source=lib/sign-module.sh
source "$ROOT/lib/sign-module.sh"
# shellcheck source=lib/package-ak3.sh
source "$ROOT/lib/package-ak3.sh"

clone_kernel
setup_toolchains
apply_kernel_patches
build_kernel_image

MODKOS=()
for m in $DEVICE_MODULES; do
  [ -f "$ROOT/modules/${m}.env" ] \
    || { echo "ERROR: modules/${m}.env not found (listed in $ENVFILE)" >&2; exit 1; }
  echo "[*] module: $m"
  build_module "$ROOT/modules/${m}.env"
done

REL="$(date +%Y%m%d)"
OUT_ZIP="${ZIP_PREFIX}-${REL}.zip"
package_ak3 "$KIMAGE_PATH" "$OUT_ZIP" \
  "$ROOT/devices/$DEVICE/anykernel.sh" ${MODKOS[@]+"${MODKOS[@]}"}

echo "[*] done: $OUT_ZIP (+ $OUT_ZIP.sha256)"
