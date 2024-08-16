#!/bin/sh

set -e

if [ "$#" != 0 ]; then
    tdnf --installroot="$SYSROOT" --releasever=2.0 install -y "$@"
fi
