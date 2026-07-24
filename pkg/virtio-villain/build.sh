#!/bin/sh
# Build virtio-villain's static musl `init` as a tiny initramfs and dump the
# machine-readable test registry (tests.tsv) consumed by openvmm's
# virtio_villain_tests. Driven by pkg/Tools/build.sh, which exports ARCH,
# SRCDIR, SYSROOT, BUILDDIR, OUTPUTDIR and packs $SYSROOT into
# sysroot.cpio.gz (BUILD_CPIO=1), the same way the initrd package does.

set -e

# Cross-build the static init with the musl toolchain (on PATH).
make -C "$SRCDIR" TARGET="$BUILDDIR" CC="$ARCH-linux-musl-gcc"

# Install it as the initramfs /init, next to the mountpoints init mounts
# itself (/proc, /sys, /dev). The framework cpio-packs $SYSROOT.
install -Dm755 "$BUILDDIR/init" "$SYSROOT/init"
"$ARCH-linux-musl-strip" "$SYSROOT/init"
mkdir -p "$SYSROOT/proc" "$SYSROOT/sys" "$SYSROOT/dev"

# `init --list-tsv` runs on the build host (binfmt/qemu-user for cross
# targets) and dumps the test registry as TSV.
"$SYSROOT/init" --list-tsv > "$OUTPUTDIR/tests.tsv"
echo "wrote $(wc -l < "$OUTPUTDIR/tests.tsv") test rows to tests.tsv"
