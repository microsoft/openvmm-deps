#!/bin/bash
# Apply patches to the QEMU source tree.
# Called from the Dockerfile before build.sh.
set -e

cd "${SRCDIR:-/pkg/qemu/src}"

PKGDIR="${PKGDIR:-$(dirname "$0")}"
for p in "$PKGDIR"/*.patch; do
    [ -f "$p" ] || continue
    echo "Applying $(basename "$p")"
    patch -p1 < "$p"
done
