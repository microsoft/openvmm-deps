#!/bin/sh

set -e

export CXX=/pkg/Tools/c++
make -f "$SRCDIR"/Makefile
mkdir -p "$SYSROOT"/usr/lib
cp libsample.a "$SYSROOT/lib/"
