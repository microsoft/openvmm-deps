#!/bin/sh

# Builds the musl cross toolchain

set -e

# Convert the Go/Docker architecture to the gcc toolchain architecture.
case $TARGETARCH in
    amd64) ARCH=x86_64 ;;
    arm64) ARCH=aarch64 ;;
    *) >&2 echo "Unknown architecture: $TARGETARCH" && exit 1 ;;
esac

cd /cross/musl-cross-make
cp ../config.mak .
cp ../hashes/* hashes/

# Set the cross sources directory for link_source.sh.
#
# This approach, linking sources in on request from musl-cross-make, is used
# instead of just using musl-cross-make's SOURCES parameter. With the SOURCES
# override, musl-cross-make skips its hash validation step.
CROSS_SOURCES=${CROSS_SOURCES:-/sources}
export CROSS_SOURCES
sha256sum "$CROSS_SOURCES"/*

# Enable basic debug info which will generate CFI and allow WinDbg to undwind
# the call stack when musl's `syscall` function is on the top of the stack.
export CFLAGS=" -O2 -g1  -D_FORTIFY_SOURCE=2 -z noexecstack -Wl,-z,relro -Wl,-z,now -Wformat -Wformat-security -fstack-clash-protection"

if [ "$TARGETARCH" = amd64 ]; then
  export CFLAGS="$CFLAGS -fcf-protection"
fi

echo "Building MUSL with CFLAGS: $CFLAGS"
make -j`nproc` TARGET="$ARCH-linux-musl" OUTPUT=/opt/cross DL_CMD=/cross/link_source.sh install
