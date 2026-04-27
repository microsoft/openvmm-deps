#!/bin/sh

set -e

cd $SRCDIR
scripts/build.py cmake --config Release --no-fips --target symcrypt_generic_posix out
cp out/lib/libsymcrypt_generic_posix.a $SYSROOT/lib/libsymcrypt.a
