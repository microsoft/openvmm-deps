#!/bin/sh

set -e

# Change the build to produce a static library
patch -p1 < "$PKGDIR/0000-build-static.patch"
