#!/bin/sh

set -e

cd $SRCDIR

# Copy headers before build to avoid picking up generated outputs we don't want
cp inc/*.h $SYSROOT/include/

cmake -S "$SRCDIR" -B out \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DSYMCRYPT_FIPS_BUILD=OFF \
    -DSYMCRYPT_UNIT_TESTS=OFF
cmake --build out -j --target symcrypt_generic_posix

# Avoid copying all the intermediate build artifacts, we only need the final lib
cp out/lib/libsymcrypt_generic_posix.a $SYSROOT/lib/libsymcrypt.a

# Copy the one generated output header we need
cp inc/symcrypt_internal_shared.inc $SYSROOT/include/
