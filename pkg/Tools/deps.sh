#!/bin/sh

# Installs host dependencies needed by package builds.

set -e

packages="
autoconf
automake
bash
bc
binutils
bison
cmake
diffutils
flex
kernel-headers
gawk
gcc
glibc-devel
libarchive
libtool
make
meson
openssl-devel
patch
pkgconf
tar
util-linux
"

tdnf install -y $packages
