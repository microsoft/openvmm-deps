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

if [ -n "${LINUX_SOURCE_EPOCH:-}" ]; then
    export SOURCE_DATE_EPOCH="$LINUX_SOURCE_EPOCH"
    export KBUILD_BUILD_TIMESTAMP="@$LINUX_SOURCE_EPOCH"
    export KBUILD_BUILD_USER=openvmm
    export KBUILD_BUILD_HOST=openvmm
    export KBUILD_BUILD_VERSION=1
fi

make -j`nproc` -k -f $SRCDIR/Makefile ARCH="$KARCH" CROSS_COMPILE="$ARCH-linux-musl-" olddefconfig $KTARGETS

required_config="$PKGDIR/$LINUX_VERSION/required.config"
if [ -f "$required_config" ]; then
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
fi

for image in $KIMAGES; do
    cp "$image" "$SYSROOT/boot/"
done

# Export the final config (after olddefconfig) so it can be extracted and committed.
cp .config "$SYSROOT/boot/config"

if [ -n "${LINUX_SOURCE_REVISION:-}" ]; then
    kernel_release="$(make -s -f "$SRCDIR/Makefile" ARCH="$KARCH" \
        CROSS_COMPILE="$ARCH-linux-musl-" kernelrelease)"
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
    } >"$SYSROOT/boot/manifest.txt"
fi
