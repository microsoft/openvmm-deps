#!/bin/sh

set -e

cmake -GNinja -DCMAKE_INSTALL_PREFIX="$SYSROOT" -DLLVM_ENABLE_RUNTIMES="libunwind" "$SRCDIR/runtimes"
ninja install-unwind
