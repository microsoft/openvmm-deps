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
ca-certificates
cmake
curl
diffutils
elfutils-libelf-devel
erofs-utils
flex
kernel-headers
gawk
gcc
git
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

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- \
    -y --no-modify-path --default-toolchain stable --profile minimal \
    --target x86_64-unknown-linux-musl \
    --target aarch64-unknown-linux-musl
