#!/bin/bash
# Build TF-RMM for QEMU virt CCA tests.

set -euo pipefail

PKGDIR="${PKGDIR:-/pkg/rmm}"
SRCDIR="${SRCDIR:-$PKGDIR/src}"
BUILDDIR="${BUILDDIR:-/work/rmm}"
OUTPUTDIR="${OUTPUTDIR:-/out}"
RMM_VERSION="${RMM_VERSION:-7.1-rc1-kvm-cca}"
RMM_CONFIG="${RMM_CONFIG:-qemu_virt_defcfg}"

case "${TARGETARCH:-}" in
    arm64) ;;
    *) echo "TF-RMM is only built for TARGETARCH=arm64" >&2; exit 1 ;;
esac

src="$BUILDDIR/src"
build="$BUILDDIR/build"

rm -rf "$src" "$build"
mkdir -p "$src" "$build" "$OUTPUTDIR"
cp -a "$SRCDIR"/. "$src"/

for submodule in cpputest libspdm mbedtls minicoro qcbor spdm-emu t_cose; do
    rm -rf "$src/ext/$submodule"
    mkdir -p "$src/ext/$submodule"
    cp -a "$PKGDIR/submodules/$submodule"/. "$src/ext/$submodule"/
done

for patch_file in "$PKGDIR/$RMM_VERSION"/*.patch; do
    [ -f "$patch_file" ] || continue
    echo "Applying $(basename "$patch_file")"
    patch -d "$src" -p1 < "$patch_file"
done

export CROSS_COMPILE=aarch64-none-elf-

cmake -S "$src" -B "$build" -G Ninja \
    -DRMM_CONFIG="$RMM_CONFIG" \
    -DRMM_TOOLCHAIN=gnu \
    -DCMAKE_BUILD_TYPE=Release

cmake --build "$build" --target rmm --parallel

for artifact in rmm.img rmm.elf rmm_core.img rmm_core.elf rmm_core.map; do
    install -Dm644 "$build/Release/$artifact" "$OUTPUTDIR/$artifact"
done
