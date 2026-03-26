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
elfutils-libelf-devel
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
perl
pkgconf
tar
util-linux
"

tdnf install -y $packages
