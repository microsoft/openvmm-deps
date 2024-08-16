#!/bin/sh

# Installs dependencies needed to build the musl cross toolchain.

set -e

packages="
git
make
gcc
g++
bash
patch
pkgconf
automake
autoconf
libtool
bison
flex
util-linux
wget
ca-certificates
tar
binutils
awk
glibc-devel
kernel-headers
diffutils
file
"

tdnf install $packages -y
