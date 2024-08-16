#!/bin/sh
set -e
set -x

"$SRCDIR/Configure" "linux-$ARCH" no-shared --cross-compile-prefix="$ARCH-linux-musl-" --prefix="$SYSROOT"
make -j`nproc`
make -j`nproc` install_sw
