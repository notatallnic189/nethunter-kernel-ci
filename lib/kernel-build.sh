#!/usr/bin/env bash
# lib/kernel-build.sh
# Kernel cloning, patching and building. All functions are plain bash, no
# secrets, and every knob comes from the caller (build.sh reads it from
# devices/<device>/device.env).
#
# Inputs expected from the caller:
#   KERNEL_REPO      kernel git URL                     (required)
#   KERNEL_BRANCH    kernel git branch                  (required)
#   KERNEL_REF       pin the kernel to an exact commit  (optional, overrides branch)
#   DEFCONFIG        defconfig make target name         (required)
#   KERNEL_IMAGE     boot image target, e.g. Image.gz-dtb or vmlinux (required)
#   PROTON_REPO      clang toolchain git URL            (optional, proton-clang default)
#   PROTON_REF       pin proton-clang to an exact commit (optional)
#   ARMTC_REPO       arm32 gcc toolchain git URL        (optional)
#   ARMTC_REF        pin the arm32 gcc to an exact commit (optional)
#   ARCH             arm64 by default
#   ROOT             template repo root (for device defconfig + patches)
#   DEVICE           device name (optional: no defconfig file, no patches)
#   DEFCONFIG_FILE   explicit defconfig file path (overrides devices/<d>/defconfig)
#   WORKDIR          scratch dir
#
# Outputs set for the caller:
#   KSRC             kernel out dir
#   KIMAGE_PATH      absolute path of the built image
#   CC, CROSS_COMPILE, CROSS_COMPILE_ARM32, JOBS

# clone_ref <repo> <sha> <dest>
# Shallow-fetch exactly the pinned commit. If <dest> already exists (a rerun
# in the same workspace) it is force-checked out to the pin, so leftover
# state (a previous overlay commit, a patched module tree) is discarded
# instead of leaking into the build.
clone_ref() {
  local repo="$1" sha="$2" dest="$3"
  if [ ! -d "$dest/.git" ]; then
    git init -q "$dest"
    git -C "$dest" remote add origin "$repo"
  fi
  git -C "$dest" fetch -q --depth=1 origin "$sha"
  git -C "$dest" checkout -f -q --detach FETCH_HEAD
}

setup_toolchains() {
  PROTON="$WORKDIR/proton-clang"
  echo "[*] cloning toolchains"
  if [ -n "${PROTON_REF:-}" ]; then
    clone_ref "${PROTON_REPO:-https://github.com/kdrag0n/proton-clang.git}" "$PROTON_REF" "$PROTON"
  else
    git clone --depth=1 "${PROTON_REPO:-https://github.com/kdrag0n/proton-clang.git}" "$PROTON"
  fi
  CC="$PROTON/bin/clang"
  CROSS_COMPILE="$PROTON/bin/aarch64-linux-gnu-"
  if [ -n "${ARMTC_REPO:-}" ]; then
    if [ -n "${ARMTC_REF:-}" ]; then
      clone_ref "$ARMTC_REPO" "$ARMTC_REF" "$WORKDIR/toolchain-arm"
    else
      git clone --depth=1 "$ARMTC_REPO" "$WORKDIR/toolchain-arm"
    fi
    CROSS_COMPILE_ARM32="$WORKDIR/toolchain-arm/bin/arm-linux-androideabi-"
  else
    # proton-clang ships arm-linux-gnueabi- tools; good enough for most trees
    CROSS_COMPILE_ARM32="$PROTON/bin/arm-linux-gnueabi-"
  fi
}

clone_kernel() {
  if [ -n "${KERNEL_REF:-}" ]; then
    echo "[*] cloning kernel @ $KERNEL_REF from $KERNEL_REPO"
    clone_ref "$KERNEL_REPO" "$KERNEL_REF" "$WORKDIR/kernel-src"
  else
    echo "[*] cloning kernel: ${KERNEL_BRANCH:-<default branch>} @ $KERNEL_REPO"
    if [ -n "${KERNEL_BRANCH:-}" ]; then
      git clone --depth=1 --single-branch --branch "$KERNEL_BRANCH" "$KERNEL_REPO" "$WORKDIR/kernel-src"
    else
      git clone --depth=1 "$KERNEL_REPO" "$WORKDIR/kernel-src"
    fi
  fi
  KSRC="$WORKDIR/kernel-src/out"
}

apply_kernel_patches() {
  # 1. defconfig file (only when a file is provided; a bare make target like
  #    "defconfig" that lives inside the kernel tree needs no file)
  local dfile="${DEFCONFIG_FILE:-}"
  if [ -z "$dfile" ] && [ -n "${DEVICE:-}" ]; then
    dfile="$ROOT/devices/$DEVICE/defconfig"
  fi
  if [ -n "$dfile" ]; then
    [ -f "$dfile" ] || { echo "ERROR: defconfig file not found: $dfile" >&2; exit 1; }
    mkdir -p "$WORKDIR/kernel-src/arch/$ARCH/configs"
    cp "$dfile" "$WORKDIR/kernel-src/arch/$ARCH/configs/${DEFCONFIG}"
  fi
  # 2. kernel patches: devices/<device>/patches/kernel/*.patch
  if [ -n "${DEVICE:-}" ] && [ -d "$ROOT/devices/$DEVICE/patches/kernel" ]; then
    local p
    for p in "$ROOT/devices/$DEVICE/patches/kernel/"*.patch; do
      [ -e "$p" ] || continue
      echo "[*] applying kernel patch: $(basename "$p")"
      git -C "$WORKDIR/kernel-src" apply "$p"
    done
  fi
  # 3. commit the overlay so scripts/setlocalversion reports a clean tree
  #    (an uncommitted overlay appends -dirty to the kernel release string).
  #    Fixed dates keep the overlay commit hash stable across CI runs.
  git -C "$WORKDIR/kernel-src" config user.name "nethunter-kernel-ci"
  git -C "$WORKDIR/kernel-src" config user.email "ci@users.noreply.github.com"
  git -C "$WORKDIR/kernel-src" add -A
  GIT_COMMITTER_DATE="2026-01-01T00:00:00+0000" \
  GIT_AUTHOR_DATE="2026-01-01T00:00:00+0000" \
    git -C "$WORKDIR/kernel-src" commit \
    -qm "CI overlay: defconfig + kernel patches" || true
}

build_kernel_image() {
  : "${KERNEL_IMAGE:?KERNEL_IMAGE not set (Image.gz-dtb, Image.lz4-dtb, vmlinux, ...)}"
  echo "[*] defconfig: $DEFCONFIG"
  make -C "$WORKDIR/kernel-src" O="$KSRC" ARCH="$ARCH" CC="$CC" \
    CROSS_COMPILE="$CROSS_COMPILE" CROSS_COMPILE_ARM32="$CROSS_COMPILE_ARM32" \
    "$DEFCONFIG"
  echo "[*] building $KERNEL_IMAGE"
  # A full image build is deliberate: MODVERSIONS=y kernels need the
  # Module.symvers produced by this build before any out-of-tree module can
  # link, and sign-file + signing certs come out of the same run.
  make -C "$WORKDIR/kernel-src" O="$KSRC" -j"${JOBS}" ARCH="$ARCH" CC="$CC" \
    CROSS_COMPILE="$CROSS_COMPILE" CROSS_COMPILE_ARM32="$CROSS_COMPILE_ARM32" \
    KBUILD_BUILD_USER=nethunter KBUILD_BUILD_HOST=ci \
    "$KERNEL_IMAGE"
  case "$KERNEL_IMAGE" in
    vmlinux)  KIMAGE_PATH="$KSRC/vmlinux" ;;
    *)        KIMAGE_PATH="$KSRC/arch/$ARCH/boot/$KERNEL_IMAGE" ;;
  esac
  [ -f "$KIMAGE_PATH" ] || { echo "ERROR: $KERNEL_IMAGE not produced at $KIMAGE_PATH" >&2; exit 1; }
}
