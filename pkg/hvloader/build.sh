#!/bin/bash
# Build the public HvLoader EFI application for the ARM64 MSHV Incubator.

set -euo pipefail

PKGDIR="${PKGDIR:-/pkg/hvloader}"
BUILDDIR="${BUILDDIR:-/work/hvloader}"
OUTPUTDIR="${OUTPUTDIR:-/out}"
HVLOADER_SOURCE_REVISION="${HVLOADER_SOURCE_REVISION:?}"
EDK2_SOURCE_REVISION="${EDK2_SOURCE_REVISION:?}"
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:?}"

case "${TARGETARCH:-}" in
    arm64) ;;
    *) echo "HvLoader is only built for TARGETARCH=arm64" >&2; exit 1 ;;
esac

edk2="$BUILDDIR/edk2"
export WORKSPACE="$BUILDDIR/uefi"
export CONF_PATH="$WORKSPACE/Conf"
mkdir -p "$edk2" "$CONF_PATH" "$WORKSPACE/HvLoader" "$OUTPUTDIR"
cp -a "$PKGDIR/src/edk2"/. "$edk2/"
cp -a "$PKGDIR/src/hvloader"/. "$WORKSPACE/HvLoader/"
cp "$PKGDIR/HvLoaderBuild.dsc" "$WORKSPACE/"

make -C "$edk2/BaseTools" -j"$(nproc)"
export SOURCE_DATE_EPOCH
export PACKAGES_PATH="$edk2"
export EDK_TOOLS_PATH="$edk2/BaseTools"
export GCC_AARCH64_PREFIX=aarch64-linux-gnu-
# EDK2's environment setup scripts do not support nounset.
set +u
source "$edk2/edksetup.sh"
set -u
build -a AARCH64 -b RELEASE -t GCC -p HvLoaderBuild.dsc -n "$(nproc)"

image="$WORKSPACE/Build/HvLoader/RELEASE_GCC/AARCH64/HvLoader.efi"
if [ ! -s "$image" ]; then
    echo "missing or empty HvLoader EFI application: $image" >&2
    exit 1
fi
install -m644 "$image" "$OUTPUTDIR/HvLoader.efi"
install -m644 "$WORKSPACE/HvLoader/LICENSE" "$OUTPUTDIR/LICENSE.HvLoader"
install -m644 "$edk2/License.txt" "$OUTPUTDIR/LICENSE.edk2"

cat > "$OUTPUTDIR/manifest.txt" <<EOF
architecture=aarch64
hvloader_source_revision=$HVLOADER_SOURCE_REVISION
edk2_source_revision=$EDK2_SOURCE_REVISION
source_date_epoch=$SOURCE_DATE_EPOCH
build_target=RELEASE
toolchain_tag=GCC
signed=false
hvloader_efi_sha256=$(sha256sum "$OUTPUTDIR/HvLoader.efi" | awk '{print $1}')
platform_dsc_sha256=$(sha256sum "$PKGDIR/HvLoaderBuild.dsc" | awk '{print $1}')
toolchain=$(${GCC_AARCH64_PREFIX}gcc --version | sed -n '1p')
EOF
