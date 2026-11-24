#!/usr/bin/env bash
# lib/package-ak3.sh
# package_ak3 <image-path> <out-zip-name> <device anykernel.sh> [ko...]
#
# Packages the built kernel image (and any signed .ko files) into a flashable
# AnyKernel3 zip and writes a sha256 next to it.
#
# Requires from the caller: WORKDIR, and AK3_REPO (optional, osm0sis/AnyKernel3
# default).
package_ak3() {
  local image="$1" zipname="$2" ak3sh="$3"
  shift 3
  local ak3="$WORKDIR/AnyKernel3"
  if [ ! -d "$ak3" ]; then
    echo "[*] cloning AnyKernel3"
    if [ -n "${AK3_REF:-}" ]; then
      clone_ref "${AK3_REPO:-https://github.com/osm0sis/AnyKernel3.git}" "$AK3_REF" "$ak3"
    else
      git clone --depth=1 "${AK3_REPO:-https://github.com/osm0sis/AnyKernel3.git}" "$ak3"
    fi
  fi
  echo "[*] packaging $zipname"
  cp "$image" "$ak3/$(basename "$image")"
  if [ $# -gt 0 ]; then
    mkdir -p "$ak3/modules/system/lib/modules"
    local ko
    for ko in "$@"; do
      echo "[*] zip += $(basename "$ko")"
      cp "$ko" "$ak3/modules/system/lib/modules/$(basename "$ko")"
    done
  fi
  cp "$ak3sh" "$ak3/anykernel.sh"
  rm -f "$ak3/placeholder"
  # zip from inside the tree so the zip root is the AK3 root
  ( cd "$ak3" && zip -r9 "$WORKDIR/$zipname" . \
      -x ".git/*" ".github/*" "README.md" "*.zip" ".DS_*" "*.img.gz" "placeholder" )
  ( cd "$WORKDIR" && sha256sum "$zipname" | tee "$zipname.sha256" )
  echo "[*] artifact: $WORKDIR/$zipname"
}
