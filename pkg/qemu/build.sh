#!/bin/bash
# Build statically-linked QEMU system emulators (TCG only, no accelerators).
# Supports both native and cross-compilation via $TARGETARCH.

set -e

SRCDIR="${SRCDIR:-/pkg/qemu/src}"
BUILDDIR="${BUILDDIR:-/work/qemu}"
OUTPUTDIR="${OUTPUTDIR:-/out}"

# Determine if we need to cross-compile.
HOST_ARCH=$(uname -m)
case "${TARGETARCH:-}" in
    arm64)  TARGET_ARCH=aarch64 ;;
    amd64)  TARGET_ARCH=x86_64 ;;
    *)      TARGET_ARCH="$HOST_ARCH" ;;
esac

CROSS_OPTS=()
if [ "$TARGET_ARCH" != "$HOST_ARCH" ]; then
    CROSS_OPTS+=(--cross-prefix="${TARGET_ARCH}-linux-gnu-")
fi

mkdir -p "$BUILDDIR" "$OUTPUTDIR"
cd "$BUILDDIR"

"$SRCDIR/configure" \
    "${CROSS_OPTS[@]}" \
    --target-list=aarch64-softmmu,x86_64-softmmu \
    --static \
    --without-default-features \
    --enable-system \
    --enable-tcg \
    --enable-fdt=internal \
    --enable-slirp \
    --enable-attr \
    --enable-virtfs \
    --disable-pixman \
    --disable-docs \
    --disable-install-blobs \
    -Ddefault_library=static

make -j$(nproc)

for bin in qemu-system-aarch64 qemu-system-x86_64; do
    install -Dm755 "$BUILDDIR/$bin" "$OUTPUTDIR/$bin"
    "${TARGET_ARCH}-linux-gnu-strip" "$OUTPUTDIR/$bin" 2>/dev/null \
        || strip "$OUTPUTDIR/$bin"
done
