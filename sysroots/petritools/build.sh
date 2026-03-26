#!/bin/sh
# Prune files not needed at runtime to reduce image size.
set -e

rm -rf \
    "$SYSROOT/usr/share/locale" \
    "$SYSROOT/usr/share/cracklib" \
    "$SYSROOT/usr/share/gtk-doc" \
    "$SYSROOT/usr/share/X11" \
    "$SYSROOT/usr/share/licenses" \
    "$SYSROOT/usr/share/info" \
    "$SYSROOT/usr/share/keymaps" \
    "$SYSROOT/usr/share/consolefonts" \
    "$SYSROOT/usr/share/consoletrans" \
    "$SYSROOT/usr/lib/systemd" \
    "$SYSROOT/usr/lib/udev" \
    "$SYSROOT/usr/lib/modules" \
    "$SYSROOT/usr/lib/python3"* \
    "$SYSROOT/usr/lib/locale" \
    "$SYSROOT/usr/include"
