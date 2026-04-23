#!/bin/sh

set -e

# Pending SymCrypt PR 15404945
patch -p1 < "$PKGDIR/0001-remove-RTLD_DEEPBIND.patch"
# Pending SymCrypt PR 15405250
patch -p1 < "$PKGDIR/0002-fix-getentropy.patch"