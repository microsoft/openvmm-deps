#!/bin/bash
# Install host dependencies for cross-compiling SBSA TF-A and UEFI.

set -e

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
    acpica-tools \
    build-essential \
    ca-certificates \
    device-tree-compiler \
    gcc-aarch64-linux-gnu \
    git \
    libssl-dev \
    nasm \
    patch \
    python3 \
    python3-pyelftools \
    uuid-dev
rm -rf /var/lib/apt/lists/*
