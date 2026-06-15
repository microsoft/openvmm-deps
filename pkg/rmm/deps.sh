#!/bin/bash
# Install host dependencies for building TF-RMM.

set -e

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
    ca-certificates \
    build-essential \
    cmake \
    git \
    ninja-build \
    patch \
    perl \
    python3 \
    python3-pyelftools \
    xz-utils
rm -rf /var/lib/apt/lists/*
