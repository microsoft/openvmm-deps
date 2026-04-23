#!/bin/sh

set -e

cd $SRCDIR
# Specify git metadata manually to avoid relying on the .git directory being present
SYMCRYPT_BRANCH="main" SYMCRYPT_COMMIT_HASH="748c20f1fc486beca1a2679ed06492712cfdc950" SYMCRYPT_COMMIT_TIMESTAMP="2026-03-28T19:22:38-04:00" scripts/build.py cmake --config Release --no-strip-binary out
cp out/module/generic/*.so* $SYSROOT/lib/
cp out/lib/*.a $SYSROOT/lib/
cp out/inc/*.h $SYSROOT/include/
