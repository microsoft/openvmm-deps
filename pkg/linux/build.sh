#!/bin/sh

set -e

config="$PKGDIR/$ARCH.config"

mkdir -p "$SYSROOT/boot"

case $ARCH in
    x86_64) KARCH=x86_64 ;;
    aarch64) KARCH=arm64 ;;
    *) >&2 echo "Unknown architecture: $ARCH" && exit 1 ;;
esac

case $KARCH in
    x86_64)
        KTARGETS=vmlinux
        KIMAGES="./vmlinux"
        ;;
    arm64)
        KTARGETS="vmlinux Image"
        KIMAGES="./vmlinux ./arch/arm64/boot/Image"
        ;;
    *) >&2 echo "Unknown kernel architecture: $KARCH" && exit 1 ;;
esac

if [ -f "$config" ]; then
    cp "$config" .config
    make -j`nproc` -k -f $SRCDIR/Makefile ARCH="$KARCH" CROSS_COMPILE="$ARCH-linux-musl-" olddefconfig $KTARGETS
    
    for image in $KIMAGES; do
        cp "$image" "$SYSROOT/boot/"
    done
fi
