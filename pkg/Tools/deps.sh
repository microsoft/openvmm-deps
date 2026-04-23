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
erofs-utils
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
python3
python3-pyelftools
tar
util-linux
"

tdnf install -y $packages
