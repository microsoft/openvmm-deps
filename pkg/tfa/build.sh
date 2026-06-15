#!/bin/bash
# Build TF-A for QEMU virt CCA tests with Linux direct boot.

set -euo pipefail

PKGDIR="${PKGDIR:-/pkg/tfa}"
SRCDIR="${SRCDIR:-$PKGDIR/src}"
BUILDDIR="${BUILDDIR:-/work/tfa}"
OUTPUTDIR="${OUTPUTDIR:-/out}"
TFA_VERSION="${TFA_VERSION:-7.1-rc1-kvm-cca}"
RMM_IMAGE="${RMM_IMAGE:-$PKGDIR/rmm/rmm.img}"
PRELOADED_BL33_BASE="${PRELOADED_BL33_BASE:-0x42080000}"

case "${TARGETARCH:-}" in
    arm64) ;;
    *) echo "TF-A CCA firmware is only built for TARGETARCH=arm64" >&2; exit 1 ;;
esac

if [ ! -f "$RMM_IMAGE" ]; then
    echo "missing RMM image: $RMM_IMAGE" >&2
    exit 1
fi

src="$BUILDDIR/src"
build_base="$BUILDDIR/build"
build="$build_base/qemu/release"

rm -rf "$src" "$build_base"
mkdir -p "$src" "$OUTPUTDIR"
cp -a "$SRCDIR"/. "$src"/

for patch_file in "$PKGDIR/$TFA_VERSION"/*.patch; do
    [ -f "$patch_file" ] || continue
    echo "Applying $(basename "$patch_file")"
    patch -d "$src" -p1 < "$patch_file"
done

export CROSS_COMPILE=aarch64-none-elf-

make -C "$src" -j"$(nproc)" \
    BUILD_BASE="$build_base" \
    CROSS_COMPILE="$CROSS_COMPILE" \
    PLAT=qemu \
    DEBUG=0 \
    ENABLE_FEAT_RME=1 \
    ENABLE_RMM=1 \
    QEMU_USE_GIC_DRIVER=QEMU_GICV3 \
    ARM_LINUX_KERNEL_AS_BL33=1 \
    PRELOADED_BL33_BASE="$PRELOADED_BL33_BASE" \
    RMM="$RMM_IMAGE" \
    all fip

for artifact in bl1.bin bl2.bin bl31.bin fip.bin; do
    install -Dm644 "$build/$artifact" "$OUTPUTDIR/$artifact"
done

# QEMU's qemu platform expects the FIP at PLAT_QEMU_FIP_BASE (0x40000) in
# secure flash. Package a ready-to-use flash image for `-bios flash.bin`.
truncate -s 64M "$OUTPUTDIR/flash.bin"
dd if="$build/bl1.bin" of="$OUTPUTDIR/flash.bin" bs=4096 conv=notrunc status=none
dd if="$build/fip.bin" of="$OUTPUTDIR/flash.bin" bs=4096 seek=64 conv=notrunc status=none

for artifact in bl1 bl2 bl31; do
    for ext in elf map; do
        if [ -f "$build/$artifact/$artifact.$ext" ]; then
            install -Dm644 "$build/$artifact/$artifact.$ext" "$OUTPUTDIR/$artifact.$ext"
        fi
    done
done

cat > "$OUTPUTDIR/boot-info.txt" <<EOF
TF-A platform: qemu
FEAT_RME enabled: yes
RMM enabled: yes
GIC driver: QEMU_GICV3
RMM: rmm.img from openvmm-test-rmm-$TFA_VERSION
Linux direct boot: yes
PRELOADED_BL33_BASE: $PRELOADED_BL33_BASE
ARM_PRELOADED_DTB_BASE: 0x40000000
QEMU flash FIP offset: 0x40000
EOF
