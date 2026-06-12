# syntax=docker/dockerfile:1

ARG HOST_IMAGE=mcr.microsoft.com/azurelinux/base/core:3.0
ARG TARGET_IMAGE=mcr.microsoft.com/azurelinux/base/core:3.0

# Build the musl toolchain
FROM --platform=$BUILDPLATFORM $HOST_IMAGE AS cross-builder
COPY /cross/deps.sh /cross/
RUN /cross/deps.sh
# Download sources. build.sh can do this for us, but then they won't be cached.
# Plus, this allows us to validate a SHA256 checksum instead of just SHA1.
#
# These tarballs are mirrored to the openvmm-deps `sources-v1` GitHub
# Release for build reliability (the upstream endpoints are flaky and
# break CI). The `# upstream:` comment above each ADD records the
# canonical upstream URL for cgmanifest / Component Governance; the
# bytes are sha256-pinned so the substitution is byte-equivalent.
# upstream: https://ftpmirror.gnu.org/gnu/binutils/binutils-2.33.1.tar.xz
ADD --checksum=sha256:ab66fc2d1c3ec0359b8e08843c9f33b63e8707efdff5e4cc5c200eae24722cbf --link https://github.com/microsoft/openvmm-deps/releases/download/sources-v1/binutils-2.33.1.tar.xz /sources/
# upstream: https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=3d5db9ebe860
ADD --checksum=sha256:75d5d255a2a273b6e651f82eecfabf6cbcd8eaeae70e86b417384c8f4a58d8d3 --link https://github.com/microsoft/openvmm-deps/releases/download/sources-v1/config.sub /sources/config.sub
# upstream: https://ftpmirror.gnu.org/gnu/gcc/gcc-11.5.0/gcc-11.5.0.tar.xz
ADD --checksum=sha256:a6e21868ead545cf87f0c01f84276e4b5281d672098591c1c896241f09363478 --link https://github.com/microsoft/openvmm-deps/releases/download/sources-v1/gcc-11.5.0.tar.xz /sources/
# upstream: https://ftpmirror.gnu.org/gnu/gmp/gmp-6.1.2.tar.bz2
ADD --checksum=sha256:5275bb04f4863a13516b2f39392ac5e272f5e1bb8057b18aec1c9b79d73d8fb2 --link https://github.com/microsoft/openvmm-deps/releases/download/sources-v1/gmp-6.1.2.tar.bz2 /sources/
# upstream: https://ftp.barfooze.de/pub/sabotage/tarballs/linux-headers-4.19.88-2.tar.xz
ADD --checksum=sha256:dc7abf734487553644258a3822cfd429d74656749e309f2b25f09f4282e05588 --link https://github.com/microsoft/openvmm-deps/releases/download/sources-v1/linux-headers-4.19.88-2.tar.xz /sources/
# upstream: https://ftpmirror.gnu.org/gnu/mpc/mpc-1.1.0.tar.gz
ADD --checksum=sha256:6985c538143c1208dcb1ac42cedad6ff52e267b47e5f970183a3e75125b43c2e --link https://github.com/microsoft/openvmm-deps/releases/download/sources-v1/mpc-1.1.0.tar.gz /sources/
# upstream: https://ftpmirror.gnu.org/gnu/mpfr/mpfr-4.0.2.tar.bz2
ADD --checksum=sha256:c05e3f02d09e0e9019384cdd58e0f19c64e6db1fd6f5ecf77b4b1c61ca253acc --link https://github.com/microsoft/openvmm-deps/releases/download/sources-v1/mpfr-4.0.2.tar.bz2 /sources/
# upstream: https://musl.libc.org/releases/musl-1.2.5.tar.gz
ADD --checksum=sha256:a9a118bbe84d8764da0ea0d28b3ab3fae8477fc7e4085d90102b8596fc7c75e4 --link https://github.com/microsoft/openvmm-deps/releases/download/sources-v1/musl-1.2.5.tar.gz /sources/
# musl-cross-make build system (~v0.9.10)
ADD --link https://github.com/richfelker/musl-cross-make.git#6f3701d08137496d5aac479e3a3977b5ae993c1f /cross/musl-cross-make/
COPY --link /cross /cross
ARG TARGETARCH
ENV TARGETARCH=$TARGETARCH
RUN --network=none /cross/build.sh

# Build the image for installing Mariner packages.
FROM $TARGET_IMAGE AS target-builder
ARG TARGETARCH
ENV TARGETARCH=$TARGETARCH
ENV BUILD_BASE=1
COPY --link pkg /pkg
COPY --link sysroots /sysroots

# Build the image for compiling packages from source.
FROM --platform=$BUILDPLATFORM $HOST_IMAGE AS package-builder
COPY pkg/Tools/deps.sh /pkg/Tools/
RUN /pkg/Tools/deps.sh
COPY --link pkg /pkg
COPY --link sysroots /sysroots
ENV PATH="${PATH}:/opt/cross/bin:/root/.cargo/bin"
ENV SYSROOT="/sysroot"
ARG TARGETARCH
ENV TARGETARCH=$TARGETARCH
COPY --from=cross-builder --link /opt/cross /opt/cross

# Build base image for dbgrd.
FROM target-builder AS base-dbgrd
RUN /pkg/Tools/build.sh sysroots/dbgrd
# Build dbgrd.
FROM --platform=$BUILDPLATFORM package-builder AS build-dbgrd
COPY --from=base-dbgrd --link /sysroot /sysroot
RUN BUILD_CPIO=1 /pkg/Tools/build.sh sysroots/dbgrd
FROM scratch AS result-dbgrd
COPY --from=build-dbgrd --link /out/sysroot.cpio.gz /dbgrd.cpio.gz

# Build base image for shell.
FROM target-builder AS base-shell
RUN /pkg/Tools/build.sh sysroots/shell
# Build shell.
FROM --platform=$BUILDPLATFORM package-builder AS build-shell
COPY --from=base-shell --link /sysroot /sysroot
RUN BUILD_CPIO=1 /pkg/Tools/build.sh sysroots/shell
FROM scratch AS result-shell
COPY --from=build-shell --link /out/sysroot.cpio.gz /shell.cpio.gz

# Source repositories -- pinned by commit hash.
# linux v6.1.172 (linux-6.1.y)
FROM scratch AS src-linux-6.1
ADD --link https://github.com/gregkh/linux.git#ad16b162f21d970235ced0c7e36e960c227317e8 /
# linux v6.18.33 (linux-6.18.y)
FROM scratch AS src-linux-6.18
ADD --link https://github.com/gregkh/linux.git#83657f4189612e5cbcabc3058acd36c0bd120729 /
# llvm-project (release/17.x) -- used by libunwind and sdk
FROM scratch AS src-llvm
ADD --link https://github.com/llvm/llvm-project.git#6009708b4367171ccdbf4b5905cb6a803753fe18 /
# openssl (~3.2.0-dev)
FROM scratch AS src-openssl
ADD --link https://github.com/openssl/openssl.git#27315a978e280a20c7f3ea0bfe05f6c186137625 /
# symcrypt (v103.13.0-dev)
# SymCrypt requires git metadata during its build
FROM scratch AS src-symcrypt
ADD --keep-git-dir=true --link https://github.com/microsoft/symcrypt.git#cc7902403ec3e53df9cd0f25f5775c762ca7ccb5 /
# ms-tpm-20-ref-rs (pinned by commit)
FROM scratch AS src-ms-tpm-20-ref-rs
ADD --link https://github.com/microsoft/ms-tpm-20-ref-rs.git#e0bba1e46d9cdc8630f3693e5e91f8a3be4fad7b /
# ms-tpm-20-ref (pinned by commit)
FROM scratch AS src-ms-tpm-20-ref
ADD --link https://github.com/microsoft/ms-tpm-20-ref.git#2d5660ac249293dcbaed192c70ca208d321ebf5b /
# mimalloc v2.2.4 (matches the bundled version in libmimalloc-sys 0.1.44 / mimalloc 0.1.48)
FROM scratch AS src-mimalloc
ADD --unpack --checksum=sha256:754a98de5e2912fddbeaf24830f982b4540992f1bab4a0a8796ee118e0752bda --link https://github.com/microsoft/mimalloc/archive/refs/tags/v2.2.4.tar.gz /
# qemu (v11.0.1)
FROM scratch AS src-qemu
ADD --unpack --checksum=sha256:b3c66db81b337ef296b838066d41ec479ea2172e795ee113cb30c1f982b9ca39 --link https://github.com/qemu/qemu/archive/refs/tags/v11.0.1.tar.gz /

# Build the sdk.
#
# Note that this pulls from the cross compiler and doesn't use the target
# builder.
FROM --platform=$BUILDPLATFORM package-builder AS build-sdk
RUN ln -s /opt/cross/*-linux-musl /sysroot
RUN --mount=type=bind,from=src-llvm,source=/,target=/pkg/libunwind/src \
    --mount=type=bind,from=src-openssl,source=/,target=/pkg/openssl3/src,rw \
    --mount=type=bind,from=src-symcrypt,source=/,target=/pkg/symcrypt/src,rw \
    --mount=type=bind,from=src-ms-tpm-20-ref-rs,source=/,target=/pkg/ms_tpm_20_ref/src,rw \
    --mount=type=bind,from=src-ms-tpm-20-ref,source=/,target=/pkg/ms_tpm_20_ref/src/ms-tpm-20-ref,rw \
    --mount=type=bind,from=src-mimalloc,source=/mimalloc-2.2.4,target=/pkg/mimalloc/src \
    /pkg/Tools/build.sh sysroots/sdk
FROM scratch AS result-sdk
COPY --from=build-sdk --link /out/sysroot.tar.gz /sysroot.tar.gz

# Build base image for initrd.
FROM target-builder AS base-initrd
RUN /pkg/Tools/build.sh sysroots/initrd
# Build the Linux initrd.
FROM --platform=$BUILDPLATFORM package-builder AS build-initrd
COPY --from=base-initrd --link /sysroot /sysroot
RUN BUILD_CPIO=1 /pkg/Tools/build.sh sysroots/initrd
FROM scratch AS result-initrd
COPY --from=build-initrd --link /out/sysroot.cpio.gz /initrd

# Build the Linux test kernels. One stage per kernel version; each stage
# bind-mounts its pinned source and reads its config from
# pkg/linux/<version>/<arch>.config (driven by $LINUX_VERSION exported via
# sysroots/linux-<version>/deps). The kernel result contains only the
# kernel images and final config; the initrd ships as its own artifact and
# is shared across all kernel versions. To add a new kernel line, add a
# matching `src-linux-<ver>` source stage above and a `build-linux-<ver>` /
# `result-linux-<ver>` pair here, then add a `COPY --from=result-linux-<ver>`
# line in the final `output` stage.
FROM --platform=$BUILDPLATFORM package-builder AS build-linux-6.1
RUN --mount=type=bind,from=src-linux-6.1,source=/,target=/pkg/linux/src \
    /pkg/Tools/build.sh sysroots/linux-6.1
FROM scratch AS result-linux-6.1
COPY --from=build-linux-6.1 --link /sysroot/boot /

FROM --platform=$BUILDPLATFORM package-builder AS build-linux-6.18
RUN --mount=type=bind,from=src-linux-6.18,source=/,target=/pkg/linux/src \
    /pkg/Tools/build.sh sysroots/linux-6.18
FROM scratch AS result-linux-6.18
COPY --from=build-linux-6.18 --link /sysroot/boot /

FROM --platform=$BUILDPLATFORM package-builder AS result-libunwind
RUN --mount=type=bind,from=src-llvm,source=/,target=/pkg/libunwind/src \
    /pkg/Tools/build.sh pkg/libunwind
RUN find /sysroot

# Build base image for petritools.
FROM target-builder AS base-petritools
RUN /pkg/Tools/build.sh sysroots/petritools
# Build petritools as EROFS image.
FROM --platform=$BUILDPLATFORM package-builder AS build-petritools
COPY --from=base-petritools --link /sysroot /sysroot
RUN BUILD_EROFS=1 /pkg/Tools/build.sh sysroots/petritools
FROM scratch AS result-petritools
COPY --from=build-petritools --link /out/sysroot.erofs /petritools.erofs

# Build QEMU (statically linked, TCG only).
# Uses Ubuntu for multiarch cross-compilation support.
FROM --platform=$BUILDPLATFORM ubuntu:24.04 AS build-qemu
ARG TARGETARCH
ENV TARGETARCH=$TARGETARCH
COPY --link pkg/qemu/deps.sh /pkg/qemu/deps.sh
RUN /pkg/qemu/deps.sh
COPY --link pkg/qemu /pkg/qemu
RUN --mount=type=bind,from=src-qemu,source=/qemu-11.0.1,target=/pkg/qemu/src,rw \
    cd /pkg/qemu/src && /pkg/qemu/patch.sh && /pkg/qemu/build.sh
FROM scratch AS result-qemu
COPY --from=build-qemu --link /out/ /

# Build the output. The release workflow packs each top-level subdirectory
# into its own GitHub release artifact:
#   openvmm-deps/  -> openvmm-deps.<arch>.<release>.tar.gz
#   initrd/        -> openvmm-test-initrd.<arch>.<release>.tar.gz
#   linux-<kver>/  -> openvmm-test-linux-<kver>.<arch>.<release>.tar.gz
FROM scratch AS output
COPY --from=result-dbgrd      --link / /openvmm-deps/
COPY --from=result-shell      --link / /openvmm-deps/
COPY --from=result-sdk        --link / /openvmm-deps/
COPY --from=result-petritools --link / /openvmm-deps/
COPY --from=result-initrd     --link /initrd /initrd/initrd
COPY --from=result-linux-6.1  --link / /linux-6.1/
COPY --from=result-linux-6.18 --link / /linux-6.18/
COPY --from=result-qemu       --link / /qemu/
