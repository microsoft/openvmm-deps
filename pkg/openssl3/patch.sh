#!/bin/sh

set -e

patch -p1 < "$PKGDIR/0001-Disable-avx512-assembly-routines.patch"
