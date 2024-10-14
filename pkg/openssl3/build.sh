#!/bin/sh
set -e
set -x

"$SRCDIR/Configure" "linux-$ARCH" no-shared --cross-compile-prefix="$ARCH-linux-musl-" --prefix="$SYSROOT" -fno-asynchronous-unwind-tables
make -j`nproc`
make -j`nproc` install_sw
