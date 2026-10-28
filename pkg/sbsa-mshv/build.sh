#!/bin/bash
# Build the paired SBSA flash images used by the ARM64 MSHV Incubator.

set -euo pipefail

PKGDIR="${PKGDIR:-/pkg/sbsa-mshv}"
BUILDDIR="${BUILDDIR:-/work/sbsa-mshv}"
OUTPUTDIR="${OUTPUTDIR:-/out}"
TFA_SOURCE_REVISION="${TFA_SOURCE_REVISION:?}"
EDK2_SOURCE_REVISION="${EDK2_SOURCE_REVISION:?}"
EDK2_PLATFORMS_SOURCE_REVISION="${EDK2_PLATFORMS_SOURCE_REVISION:?}"
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:?}"

case "${TARGETARCH:-}" in
    arm64) ;;
    *) echo "SBSA MSHV firmware is only built for TARGETARCH=arm64" >&2; exit 1 ;;
esac

mkdir -p "$BUILDDIR" "$OUTPUTDIR"
cp -a "$PKGDIR/src/tfa" "$BUILDDIR/tfa"
cp -a "$PKGDIR/src/edk2" "$BUILDDIR/edk2"
cp -a "$PKGDIR/src/edk2-platforms" "$BUILDDIR/edk2-platforms"

tfa="$BUILDDIR/tfa"
edk2="$BUILDDIR/edk2"
platforms="$BUILDDIR/edk2-platforms"
inputs="$BUILDDIR/firmware-inputs/Platform/Qemu/Sbsa"

# Normalize the patched files so the checked-in patches can use LF endings.
sed -i 's/\r$//' \
    "$edk2/ArmPkg/Library/PlatformBootManagerLib/PlatformBm.c" \
    "$edk2/ArmPkg/Library/PlatformBootManagerLib/PlatformBootManagerLib.inf"
patch -d "$edk2" -p1 < "$PKGDIR/patches/0001-edk2-hvloader-memory-attributes-workaround.patch"

export SOURCE_DATE_EPOCH
export CROSS_COMPILE=aarch64-linux-gnu-

make -C "$tfa" -j"$(nproc)" \
    CROSS_COMPILE="$CROSS_COMPILE" \
    PLAT=qemu_sbsa DEBUG=1 ENABLE_RME=0 all fip
mkdir -p "$inputs"
install -m644 "$tfa/build/qemu_sbsa/debug/bl1.bin" \
    "$tfa/build/qemu_sbsa/debug/fip.bin" "$inputs/"

make -C "$edk2/BaseTools" -j"$(nproc)"
export WORKSPACE="$BUILDDIR/uefi"
export CONF_PATH="$WORKSPACE/Conf"
export PACKAGES_PATH="$edk2:$platforms:$BUILDDIR/firmware-inputs"
export EDK_TOOLS_PATH="$edk2/BaseTools"
export GCC_AARCH64_PREFIX="$CROSS_COMPILE"
mkdir -p "$CONF_PATH"
# EDK2's environment setup scripts do not support nounset.
set +u
source "$edk2/edksetup.sh"
set -u
build -a AARCH64 -b RELEASE -t GCC \
    -p Platform/Qemu/SbsaQemu/SbsaQemu.dsc \
    --pcd gUefiOvmfPkgTokenSpaceGuid.PcdUninstallMemAttrProtocol=TRUE \
    -n "$(nproc)"

for image in SBSA_FLASH0.fd SBSA_FLASH1.fd; do
    source_image="$WORKSPACE/Build/SbsaQemu/RELEASE_GCC/FV/$image"
    if [ ! -s "$source_image" ] || [ "$(stat -c %s "$source_image")" -gt 268435456 ]; then
        echo "missing, empty, or oversized SBSA flash image: $source_image" >&2
        exit 1
    fi
    install -m644 "$source_image" "$OUTPUTDIR/$image"
    truncate -s 256M "$OUTPUTDIR/$image"
done

cat > "$OUTPUTDIR/manifest.txt" <<EOF
architecture=aarch64
platform=qemu_sbsa
tfa_source_revision=$TFA_SOURCE_REVISION
edk2_source_revision=$EDK2_SOURCE_REVISION
edk2_platforms_source_revision=$EDK2_PLATFORMS_SOURCE_REVISION
source_date_epoch=$SOURCE_DATE_EPOCH
tfa_debug=1
uefi_build_target=RELEASE
uefi_toolchain=GCC
rme_enabled=false
rmm_enabled=false
uninstall_memory_attribute_protocol=true
flash_size=268435456
flash0_sha256=$(sha256sum "$OUTPUTDIR/SBSA_FLASH0.fd" | awk '{print $1}')
flash1_sha256=$(sha256sum "$OUTPUTDIR/SBSA_FLASH1.fd" | awk '{print $1}')
edk2_patch_sha256=$(sha256sum "$PKGDIR/patches/0001-edk2-hvloader-memory-attributes-workaround.patch" | awk '{print $1}')
toolchain=$(${CROSS_COMPILE}gcc --version | sed -n '1p')
EOF
