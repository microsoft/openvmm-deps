#!/bin/sh
# Build mimalloc as a static library for the sdk sysroot.
#
# Mirrors what `libmimalloc-sys`'s build.rs does (compile `src/static.c` --
# the upstream "unity" translation unit -- with a small set of defines).
#
# We produce both the default and `MI_SECURE=4` flavors so consumers can
# pick the matching `mimalloc/secure` Cargo feature. Only the public
# `mimalloc.h` is installed.
set -e
set -x

CC="${CC:-$ARCH-linux-musl-gcc}"
AR="${AR:-$ARCH-linux-musl-ar}"

# Match libmimalloc-sys: include the public + private mimalloc headers,
# disable debug asserts (release build), silence date-time warnings, and
# use the `initial-exec` TLS model.
MI_CFLAGS="\
    -I${SRCDIR}/include \
    -I${SRCDIR}/src \
    -DMI_DEBUG=0 \
    -Wno-error=date-time \
    -ftls-model=initial-exec \
    -O2"

build_variant() {
    name=$1
    extra=$2
    obj="$BUILDDIR/$name.o"
    lib="$BUILDDIR/lib$name.a"
    rm -f "$obj" "$lib"
    $CC $CFLAGS $MI_CFLAGS $extra -c "${SRCDIR}/src/static.c" -o "$obj"
    $AR rcs "$lib" "$obj"
    install -m 644 "$lib" "$SYSROOT/lib/lib$name.a"
}

build_variant mimalloc        ""
build_variant mimalloc-secure "-DMI_SECURE=4"

install -m 644 "$SRCDIR/include/mimalloc.h" "$SYSROOT/include/mimalloc.h"
