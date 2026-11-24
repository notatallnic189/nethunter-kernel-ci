#!/usr/bin/env bash
# lib/build-module.sh
# build_module <path/to/module.env>
#
# Clones one out-of-tree module, applies device driver patches, builds it
# against the kernel built in $WORKDIR/kernel-src, signs it and appends the
# .ko path to the MODKOS array.
#
# Module env variables (see modules/*.env for the shipped examples):
#   MODULE_NAME     directory name to clone into          (required)
#   MODULE_REPO     module git URL                        (required)
#   MODULE_KO       produced kernel object, e.g. 88XXau.ko (required)
#   MODULE_STYLE    "dir"  : run make inside the module dir, KSRC= kernel out dir
#                   "ksrc" : run make inside the kernel tree, M=<module>/<MODULE_M>
#                   (default: dir)
#   MODULE_M        subdir for ksrc style (default: src)
#   MODULE_TARGET   extra make target for dir style (optional)
#   MODULE_KCFLAGS  extra KCFLAGS (optional)
#
# Device patches: devices/<device>/patches/driver/<MODULE_NAME>-*.patch are
# applied inside the module source when DEVICE is set.
#
# Requires from the caller: WORKDIR, ROOT, ARCH, CC, CROSS_COMPILE,
# CROSS_COMPILE_ARM32, JOBS, KSRC, and sign_module() from lib/sign-module.sh.
build_module() {
  local envfile="$1"
  # shellcheck disable=SC1090
  source "$envfile"
  : "${MODULE_NAME:?MODULE_NAME missing in $envfile}"
  : "${MODULE_REPO:?MODULE_REPO missing in $envfile}"
  : "${MODULE_KO:?MODULE_KO missing in $envfile}"

  local moddir="$WORKDIR/$MODULE_NAME"
  echo "[*] cloning module $MODULE_NAME"
  if [ -n "${MODULE_REF:-}" ]; then
    clone_ref "$MODULE_REPO" "$MODULE_REF" "$moddir"
  else
    git clone --depth=1 "$MODULE_REPO" "$moddir"
  fi

  if [ -n "${DEVICE:-}" ] && [ -d "$ROOT/devices/$DEVICE/patches/driver" ]; then
    local p
    for p in "$ROOT/devices/$DEVICE/patches/driver/${MODULE_NAME}"-*.patch; do
      [ -e "$p" ] || continue
      echo "[*] applying module patch: $(basename "$p")"
      git -C "$moddir" apply "$p"
    done
  fi

  echo "[*] building $MODULE_NAME (${MODULE_STYLE:-dir} style)"
  case "${MODULE_STYLE:-dir}" in
    dir)
      make -C "$moddir" -j"$JOBS" ARCH="$ARCH" CC="$CC" \
        CROSS_COMPILE="$CROSS_COMPILE" CROSS_COMPILE_ARM32="$CROSS_COMPILE_ARM32" \
        KSRC="$KSRC" KCFLAGS="${MODULE_KCFLAGS:-}" ${MODULE_TARGET:-}
      ;;
    ksrc)
      make -C "$WORKDIR/kernel-src" O="$KSRC" -j"$JOBS" ARCH="$ARCH" CC="$CC" \
        CROSS_COMPILE="$CROSS_COMPILE" CROSS_COMPILE_ARM32="$CROSS_COMPILE_ARM32" \
        M="$moddir/${MODULE_M:-src}" KCFLAGS="${MODULE_KCFLAGS:-}" modules
      ;;
    *)
      echo "ERROR: unknown MODULE_STYLE '${MODULE_STYLE}' (dir|ksrc)" >&2
      exit 1
      ;;
  esac

  local ko
  ko="$(find "$moddir" -name "$MODULE_KO" -print -quit)"
  [ -n "$ko" ] || ko="$(find "$KSRC" -name "$MODULE_KO" -print -quit)"
  [ -n "$ko" ] || { echo "ERROR: $MODULE_KO not produced" >&2; exit 1; }

  sign_module "$ko"
  MODKOS+=("$ko")
  echo "[*] module ready: $ko"
}
