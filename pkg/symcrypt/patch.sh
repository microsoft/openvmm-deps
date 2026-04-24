#!/bin/sh

set -e

# Change the build to produce a static library
patch -p1 < "$PKGDIR/0000-build-static.patch"
# Pending SymCrypt PR 15404945
patch -p1 < "$PKGDIR/0001-remove-RTLD_DEEPBIND.patch"
# Pending SymCrypt PR 15405250
patch -p1 < "$PKGDIR/0002-fix-getentropy.patch"
