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
RUST_TOOLCHAIN="1.96.0"

case "$(uname -m)" in
    x86_64)
        rustup_arch="x86_64-unknown-linux-musl"
        rustup_init_sha256="9cd3fda5fd293890e36ab271af6a786ee22084b5f6c2b83fd8323cec6f0992c1"
        ;;
    aarch64)
        rustup_arch="aarch64-unknown-linux-musl"
        rustup_init_sha256="88761caacddb92cd79b0b1f939f3990ba1997d701a38b3e8dd6746a562f2a759"
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
