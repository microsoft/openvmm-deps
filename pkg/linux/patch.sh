#!/bin/sh

set -e

PKGDIR="${PKGDIR:-$(dirname "$0")}"
SRCDIR="${SRCDIR:-$PKGDIR/src}"
PATCHDIR="$PKGDIR/$LINUX_VERSION"

cd "$SRCDIR"

for p in "$PATCHDIR"/*.patch; do
    [ -f "$p" ] || continue
    echo "Applying $(basename "$p")"
    patch -p1 < "$p"
done
