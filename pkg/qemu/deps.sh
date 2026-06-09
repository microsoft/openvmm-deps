#!/bin/bash
# Install host dependencies for building QEMU.
# Handles multiarch setup for cross-compilation when TARGETARCH != host.

set -e

export DEBIAN_FRONTEND=noninteractive

HOST_ARCH=$(dpkg --print-architecture)
CROSS_ARCH="${TARGETARCH:-$HOST_ARCH}"

PACKAGES="
    gcc
    make
    ninja-build
    python3
    python3-venv
    pkg-config
    libglib2.0-dev:$HOST_ARCH
    libglib2.0-dev:$CROSS_ARCH
    zlib1g-dev:$CROSS_ARCH
    flex
    bison
    git
    patch

"

if [ "$CROSS_ARCH" != "$HOST_ARCH" ]; then
    apt-get update
    apt-get install -y ca-certificates
    dpkg --add-architecture "$CROSS_ARCH"

    # On Ubuntu, non-native architectures need the ports mirror.
    # Pin existing repos to the host arch, then add ports for the cross arch.
    if [ "$HOST_ARCH" = "amd64" ]; then
        CROSS_GCC=gcc-aarch64-linux-gnu
        CROSS_LIBC=libc6-dev-arm64-cross
        PORTS_URI=https://ports.ubuntu.com/
    else
        CROSS_GCC=gcc-x86-64-linux-gnu
        CROSS_LIBC=libc6-dev-amd64-cross
        PORTS_URI=https://archive.ubuntu.com/ubuntu
    fi

    sed -i "/^Types:/a Architectures: $HOST_ARCH" /etc/apt/sources.list.d/ubuntu.sources
    cat > /etc/apt/sources.list.d/ubuntu-ports.sources <<EOF
Types: deb
URIs: $PORTS_URI
Suites: noble noble-updates noble-security
Components: main universe
Architectures: $CROSS_ARCH
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

    PACKAGES="$PACKAGES $CROSS_GCC $CROSS_LIBC"
fi

apt-get update
apt-get install -y --no-install-recommends $PACKAGES
