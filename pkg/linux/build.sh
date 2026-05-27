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

mkdir -p "$SYSROOT/boot" "$SYSROOT/debug"

case $ARCH in
    x86_64) KARCH=x86_64 ;;
    aarch64) KARCH=arm64 ;;
    *) >&2 echo "Unknown architecture: $ARCH" && exit 1 ;;
esac

case $KARCH in
    x86_64)
        KTARGETS="vmlinux bzImage"
        KBOOTIMAGE="./arch/x86/boot/bzImage"
        ;;
    arm64)
        KTARGETS="vmlinux Image"
        KBOOTIMAGE="./arch/arm64/boot/Image"
        ;;
    *) >&2 echo "Unknown kernel architecture: $KARCH" && exit 1 ;;
esac

cp "$config" .config
make -j`nproc` -k -f $SRCDIR/Makefile ARCH="$KARCH" CROSS_COMPILE="$ARCH-linux-musl-" olddefconfig $KTARGETS

# Split vmlinux into a stripped kernel and a separate vmlinux.debug
# symbol file (linked back via .gnu_debuglink, so gdb/crash/drgn pick it
# up automatically when both files live in the same directory). The
# stripped vmlinux ships with the bootable kernel artifact; the debug
# file ships in its own debug artifact (see pkg/linux/README.md).
OBJCOPY="$ARCH-linux-musl-objcopy"
"$OBJCOPY" --only-keep-debug ./vmlinux "$SYSROOT/debug/vmlinux.debug"
"$OBJCOPY" --strip-debug ./vmlinux "$SYSROOT/boot/vmlinux"
"$OBJCOPY" --add-gnu-debuglink="$SYSROOT/debug/vmlinux.debug" "$SYSROOT/boot/vmlinux"

cp "$KBOOTIMAGE" "$SYSROOT/boot/"

# Export the final config (after olddefconfig) so it can be extracted and committed.
cp .config "$SYSROOT/boot/config"
