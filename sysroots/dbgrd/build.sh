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
    "$SYSROOT/usr/share/misc" \
    "$SYSROOT/usr/share/i18n" \
    "$SYSROOT/usr/lib/locale" \
    "$SYSROOT/usr/lib/systemd" \
    "$SYSROOT/usr/include"

# Remove static libraries.
find "$SYSROOT" -name '*.a' -delete

# Remove python modules not needed for gdb.
rm -rf \
    "$SYSROOT/usr/lib/python3"*/config-* \
    "$SYSROOT/usr/lib/python3"*/ensurepip \
    "$SYSROOT/usr/lib/python3"*/idlelib \
    "$SYSROOT/usr/lib/python3"*/lib2to3 \
    "$SYSROOT/usr/lib/python3"*/tkinter \
    "$SYSROOT/usr/lib/python3"*/turtledemo \
    "$SYSROOT/usr/lib/python3"*/pydoc_data

# Remove python bytecode caches.
find "$SYSROOT" -type d -name '__pycache__' -exec rm -rf {} +
