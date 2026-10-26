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

case "${LINUX_MODULES:-0}" in
    0) ;;
    1) KTARGETS="$KTARGETS modules" ;;
    *) >&2 echo "LINUX_MODULES must be 0 or 1" && exit 1 ;;
esac

cp "$config" .config

if [ -n "${LINUX_SOURCE_EPOCH:-}" ]; then
    export SOURCE_DATE_EPOCH="$LINUX_SOURCE_EPOCH"
    export KBUILD_BUILD_TIMESTAMP="@$LINUX_SOURCE_EPOCH"
    export KBUILD_BUILD_USER=openvmm
    export KBUILD_BUILD_HOST=openvmm
    export KBUILD_BUILD_VERSION=1
fi

make -j`nproc` -k -f $SRCDIR/Makefile ARCH="$KARCH" CROSS_COMPILE="$ARCH-linux-musl-" olddefconfig $KTARGETS

for required_config in "$PKGDIR/$LINUX_VERSION/required.config" \
    "$PKGDIR/$LINUX_VERSION/required.$ARCH.config"; do
    [ -f "$required_config" ] || continue
    while IFS= read -r setting; do
        case "$setting" in
            "") continue ;;
            "# CONFIG_"*" is not set") ;;
            \#*) continue ;;
        esac
        if ! grep -Fxq "$setting" .config; then
            >&2 echo "resolved kernel config is missing required setting: $setting"
            exit 1
        fi
    done <"$required_config"
done

kernel_release="$(make -s -f "$SRCDIR/Makefile" ARCH="$KARCH" \
    CROSS_COMPILE="$ARCH-linux-musl-" kernelrelease)"

for image in $KIMAGES; do
    cp "$image" "$SYSROOT/boot/"
done

# Export the final config (after olddefconfig) so it can be extracted and committed.
cp .config "$SYSROOT/boot/config"

# Install modules under lib/modules/<release> in the kernel artifact. The
# module signing key is generated in this build directory and not exported.
if [ "${LINUX_MODULES:-0}" = 1 ]; then
    if ! grep -Fxq CONFIG_MODULES=y .config; then
        >&2 echo "LINUX_MODULES=1 requires CONFIG_MODULES=y"
        exit 1
    fi
    if ! command -v depmod >/dev/null; then
        >&2 echo "LINUX_MODULES=1 requires depmod"
        exit 1
    fi
    make -j`nproc` -f "$SRCDIR/Makefile" ARCH="$KARCH" CROSS_COMPILE="$ARCH-linux-musl-" \
        INSTALL_MOD_PATH="$SYSROOT/boot" INSTALL_MOD_STRIP=1 modules_install
    modules_dir="$SYSROOT/boot/lib/modules/$kernel_release"
    # Drop links back into this build tree.
    rm -f "$modules_dir/build" "$modules_dir/source"
fi

if [ -n "${LINUX_SOURCE_REVISION:-}" ]; then
    {
        echo "revision=$LINUX_SOURCE_REVISION"
        echo "source_epoch=${LINUX_SOURCE_EPOCH:-}"
        echo "kernel_release=$kernel_release"
        echo "architecture=$ARCH"
        echo "toolchain=$("$ARCH-linux-musl-gcc" --version | sed -n '1p')"
        echo "config_sha256=$(sha256sum "$SYSROOT/boot/config" | awk '{print $1}')"
        for image in $KIMAGES; do
            name="$(basename "$image")"
            echo "${name}_sha256=$(sha256sum "$SYSROOT/boot/$name" | awk '{print $1}')"
        done
        if [ "${LINUX_MODULES:-0}" = 1 ]; then
            echo "modules_count=$(find "$modules_dir" -type f -name '*.ko' | wc -l)"
            echo "modules_sha256=$(cd "$SYSROOT/boot" && find lib -type f | LC_ALL=C sort | xargs sha256sum | sha256sum | awk '{print $1}')"
        fi
    } >"$SYSROOT/boot/manifest.txt"
fi
