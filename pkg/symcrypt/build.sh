#!/bin/sh

set -e

cd $SRCDIR

# Copy headers before build to avoid picking up generated outputs we don't want
cp inc/*.h $SYSROOT/include/

scripts/build.py cmake --config Release --no-fips --target symcrypt_generic_posix out

# Avoid copying all the intermediate build artifacts, we only need the final lib
cp out/lib/libsymcrypt_generic_posix.a $SYSROOT/lib/libsymcrypt.a

# Copy the one generated output header we need
cp inc/symcrypt_internal_shared.inc $SYSROOT/include/
