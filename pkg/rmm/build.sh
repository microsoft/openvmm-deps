#!/bin/bash
# Build TF-RMM for QEMU virt CCA tests.

set -euo pipefail

PKGDIR="${PKGDIR:-/pkg/rmm}"
SRCDIR="${SRCDIR:-$PKGDIR/src}"
BUILDDIR="${BUILDDIR:-/work/rmm}"
OUTPUTDIR="${OUTPUTDIR:-/out}"
RMM_FLAVOR="${RMM_FLAVOR:-cca}"
RMM_CONFIG="${RMM_CONFIG:-qemu_virt_defcfg}"
RMM_SOURCE_REVISION="${RMM_SOURCE_REVISION:?}"
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:?}"

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

for patch_file in "$PKGDIR/$RMM_FLAVOR"/*.patch; do
    [ -f "$patch_file" ] || continue
    echo "Applying $(basename "$patch_file")"
    patch -d "$src" -p1 < "$patch_file"
done

export CROSS_COMPILE=aarch64-none-elf-
export SOURCE_DATE_EPOCH

cmake -S "$src" -B "$build" -G Ninja \
    -DRMM_CONFIG="$RMM_CONFIG" \
    -DRMM_TOOLCHAIN=gnu \
    -DCMAKE_BUILD_TYPE=Release

cmake --build "$build" --target rmm --parallel

artifact_dir=
for candidate in "$build/Release" "$build"; do
    if [ -f "$candidate/rmm.img" ]; then
        artifact_dir="$candidate"
        break
    fi
done

if [ -z "$artifact_dir" ]; then
    echo "missing TF-RMM artifacts under $build/Release or $build" >&2
    find "$build" -maxdepth 2 -type f \( -name 'rmm*.img' -o -name 'rmm*.elf' -o -name 'rmm*.map' \) >&2
    exit 1
fi

for artifact in rmm.img rmm.elf rmm_core.img rmm_core.elf rmm_core.map; do
    install -Dm644 "$artifact_dir/$artifact" "$OUTPUTDIR/$artifact"
done

cat >"$OUTPUTDIR/manifest.txt" <<EOF
architecture=aarch64
config=$RMM_CONFIG
cpputest_revision=67d2dfd41e13f09ff218aa08e2d35f1c32f032a1
libspdm_revision=5ebe5e3946b9439928fa3a7548268c29cccc1b16
mbedtls_revision=107ea89daaefb9867ea9121002fbbdf926780e98
minicoro_revision=02dad0f8b7cbb12fe6e216ae7a76db15ca55cd7b
patch_sha256=$(sha256sum "$PKGDIR/$RMM_FLAVOR/0001-Skip-submodule-update-for-pinned-openvmm-deps-build.patch" | awk '{print $1}')
qcbor_revision=92d3f89030baff4af7be8396c563e6c8ef263622
rmm_core_elf_sha256=$(sha256sum "$OUTPUTDIR/rmm_core.elf" | awk '{print $1}')
rmm_core_img_sha256=$(sha256sum "$OUTPUTDIR/rmm_core.img" | awk '{print $1}')
rmm_core_map_sha256=$(sha256sum "$OUTPUTDIR/rmm_core.map" | awk '{print $1}')
rmm_elf_sha256=$(sha256sum "$OUTPUTDIR/rmm.elf" | awk '{print $1}')
rmm_img_sha256=$(sha256sum "$OUTPUTDIR/rmm.img" | awk '{print $1}')
source_date_epoch=$SOURCE_DATE_EPOCH
source_revision=$RMM_SOURCE_REVISION
spdm_emu_revision=8528ec237824dae97b8db64faadfe216d55eaf6f
t_cose_revision=117159b95608ce236bd69e6384e1319d7a212107
toolchain=$(${CROSS_COMPILE}gcc --version | sed -n '1p')
EOF
