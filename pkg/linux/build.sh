#!/bin/sh

set -e

if [ -z "$LINUX_VERSION" ]; then
    >&2 echo "LINUX_VERSION must be set (e.g. via sysroots/linux-<ver>/deps)"
    exit 1
fi

config="$PKGDIR/$LINUX_VERSION/$ARCH.config"

if [ ! -f "$config" ]; then
    >&2 echo "missing kernel config: $config"
    exit 1
fi

mkdir -p "$SYSROOT/boot"

case $ARCH in
    x86_64) KARCH=x86_64 ;;
    aarch64) KARCH=arm64 ;;
    *) >&2 echo "Unknown architecture: $ARCH" && exit 1 ;;
esac

case $KARCH in
    x86_64)
        KTARGETS="vmlinux bzImage"
        KIMAGES="./vmlinux ./arch/x86/boot/bzImage"
        ;;
    arm64)
        KTARGETS="vmlinux Image"
        KIMAGES="./vmlinux ./arch/arm64/boot/Image"
        ;;
    *) >&2 echo "Unknown kernel architecture: $KARCH" && exit 1 ;;
esac

cp "$config" .config
make -j`nproc` -k -f $SRCDIR/Makefile ARCH="$KARCH" CROSS_COMPILE="$ARCH-linux-musl-" olddefconfig $KTARGETS

for image in $KIMAGES; do
    cp "$image" "$SYSROOT/boot/"
done

# Export the final config (after olddefconfig) so it can be extracted and committed.
cp .config "$SYSROOT/boot/config"
