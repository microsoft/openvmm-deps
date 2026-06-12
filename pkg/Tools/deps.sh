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

RUSTUP_VERSION="1.29.0"
RUST_TOOLCHAIN="1.95.0"

case "$(uname -m)" in
    x86_64)
        rustup_arch="x86_64-unknown-linux-gnu"
        rustup_init_sha256="4acc9acc76d5079515b46346a485974457b5a79893cfb01112423c89aeb5aa10"
        ;;
    aarch64)
        rustup_arch="aarch64-unknown-linux-gnu"
        rustup_init_sha256="9732d6c5e2a098d3521fca8145d826ae0aaa067ef2385ead08e6feac88fa5792"
        ;;
    *)
        echo "unsupported host architecture: $(uname -m)" >&2
        exit 1
        ;;
esac

curl --proto '=https' --tlsv1.2 -sSfo /tmp/rustup-init \
    "https://static.rust-lang.org/rustup/archive/${RUSTUP_VERSION}/${rustup_arch}/rustup-init"
echo "${rustup_init_sha256}  /tmp/rustup-init" | sha256sum -c -
chmod +x /tmp/rustup-init
/tmp/rustup-init \
    -y --no-modify-path --default-toolchain "$RUST_TOOLCHAIN" --profile minimal \
    --target x86_64-unknown-linux-musl \
    --target aarch64-unknown-linux-musl
rm /tmp/rustup-init
