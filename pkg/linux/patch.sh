#!/bin/sh

set -e

if [ -z "$LINUX_VERSION" ]; then
    >&2 echo "LINUX_VERSION must be set (e.g. via sysroots/linux-<ver>/deps)"
    exit 1
fi

PKGDIR="${PKGDIR:-$(dirname "$0")}"
SRCDIR="${SRCDIR:-$PKGDIR/src}"
PATCHDIR="$PKGDIR/$LINUX_VERSION"

cd "$SRCDIR"

for p in "$PATCHDIR"/*.patch; do
    [ -f "$p" ] || continue
    echo "Applying $(basename "$p")"
    patch -p1 < "$p"
done
