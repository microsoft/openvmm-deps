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
# linux v7.2-rc1 with the KVM CCA v15 patchset
FROM scratch AS src-linux-cca-v15
ADD --link https://gitlab.arm.com/linux-arm/linux-cca.git#4ddbc65b5b408c37605110166a8da19f4dd0e180 /
# llvm-project (release/17.x) -- used by libunwind and sdk
FROM scratch AS src-llvm
ADD --link https://github.com/llvm/llvm-project.git#6009708b4367171ccdbf4b5905cb6a803753fe18 /
# openssl (3.5.7)
FROM scratch AS src-openssl
ADD --link https://github.com/openssl/openssl.git#8cf17aaeb4599f8af87fefd810b5b5fee90fe69e /
# symcrypt (v103.13.0)
# SymCrypt requires git metadata during its build
FROM scratch AS src-symcrypt
ADD --keep-git-dir=true --link https://github.com/microsoft/symcrypt.git#286762b7730e2b780678f5ab11fef2b1bad639e0 /
# ms-tpm-20-ref-rs (pinned by commit)
FROM scratch AS src-ms-tpm-20-ref-rs
ADD --link https://github.com/microsoft/ms-tpm-20-ref-rs.git#9a24154df7b09cd1a0b90f25a7bf9cbb16e24c7d /
# ms-tpm-20-ref (pinned by commit)
FROM scratch AS src-ms-tpm-20-ref
ADD --link https://github.com/microsoft/ms-tpm-20-ref.git#2d5660ac249293dcbaed192c70ca208d321ebf5b /
# ms-tcg-tpm-sys (pinned by commit)
FROM scratch AS src-ms-tcg-tpm-sys
ADD --link https://github.com/microsoft/ms-tcg-tpm-sys.git#fd4eb893a4fa0f68bd5cae3d5e7185161e21d85f /
# TCG TPM (pinned by commit)
FROM scratch AS src-tcg-tpm
ADD --link https://github.com/TrustedComputingGroup/TPM.git#bc29a21d44b01396223c152a4834e52318591770 /
# mimalloc v2.2.4 (matches the bundled version in libmimalloc-sys 0.1.44 / mimalloc 0.1.48)
FROM scratch AS src-mimalloc
ADD --unpack --checksum=sha256:754a98de5e2912fddbeaf24830f982b4540992f1bab4a0a8796ee118e0752bda --link https://github.com/microsoft/mimalloc/archive/refs/tags/v2.2.4.tar.gz /
# qemu (v11.0.1)
FROM scratch AS src-qemu
ADD --unpack --checksum=sha256:b3c66db81b337ef296b838066d41ec479ea2172e795ee113cb30c1f982b9ca39 --link https://github.com/qemu/qemu/archive/refs/tags/v11.0.1.tar.gz /
# TF-RMM v2 integration branch, tested with the KVM CCA v15 patchset.
FROM scratch AS src-tf-rmm-cca
ADD --keep-git-dir=true --link https://github.com/TF-RMM/tf-rmm.git#f00eac344b6f7c18abc6dad1948b07e9a82ff9f0 /
# TF-A v2.15.0, used to load TF-RMM and Linux-direct BL33.
FROM scratch AS src-tfa-cca
ADD --keep-git-dir=true --link https://github.com/TrustedFirmware-A/trusted-firmware-a.git#da738d5eae93af342fdc4995dd3c05acb4c9d757 /
# TF-RMM submodules -- pinned by the TF-RMM superproject.
FROM scratch AS src-tf-rmm-cpputest
ADD --keep-git-dir=true --link https://github.com/cpputest/cpputest.git#67d2dfd41e13f09ff218aa08e2d35f1c32f032a1 /
FROM scratch AS src-tf-rmm-libspdm
ADD --keep-git-dir=true --link https://github.com/DMTF/libspdm.git#5ebe5e3946b9439928fa3a7548268c29cccc1b16 /
FROM scratch AS src-tf-rmm-mbedtls
ADD --keep-git-dir=true --link https://github.com/ARMmbed/mbedtls.git#107ea89daaefb9867ea9121002fbbdf926780e98 /
FROM scratch AS src-tf-rmm-minicoro
ADD --keep-git-dir=true --link https://github.com/edubart/minicoro.git#02dad0f8b7cbb12fe6e216ae7a76db15ca55cd7b /
FROM scratch AS src-tf-rmm-qcbor
ADD --keep-git-dir=true --link https://github.com/laurencelundblade/QCBOR.git#92d3f89030baff4af7be8396c563e6c8ef263622 /
FROM scratch AS src-tf-rmm-spdm-emu
ADD --keep-git-dir=true --link https://github.com/DMTF/spdm-emu.git#8528ec237824dae97b8db64faadfe216d55eaf6f /
FROM scratch AS src-tf-rmm-t-cose
ADD --keep-git-dir=true --link https://github.com/laurencelundblade/t_cose.git#117159b95608ce236bd69e6384e1319d7a212107 /
# Arm GNU Toolchain 13.3.rel1, required by TF-RMM.
FROM scratch AS src-arm-gnu-toolchain-aarch64-none-elf
ADD --unpack --checksum=sha256:7fedf894040580b1db747d06ac5d4263c46e591ffe7695656d1da5accb00a159 --link https://developer.arm.com/-/media/Files/downloads/gnu/13.3.rel1/binrel/arm-gnu-toolchain-13.3.rel1-x86_64-aarch64-none-elf.tar.xz /
# virtio-villain -- guest-side virtio protocol conformance/fault-injection
# suite. Pinned to the v0.6.0 release commit.
FROM scratch AS src-virtio-villain
ADD --link https://github.com/weltling/virtio-villain.git#ce7886f63ec5f6a7ee8215b3517a3f3c42f42ea4 /

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
    --mount=type=bind,from=src-ms-tcg-tpm-sys,source=/,target=/pkg/ms_tcg_tpm_sys/src,rw \
    --mount=type=bind,from=src-tcg-tpm,source=/,target=/pkg/ms_tcg_tpm_sys/src/TPM,rw \
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

# Build virtio-villain: cross-compile the static musl `init`, pack it into a
# cpio initramfs (BUILD_CPIO, like the initrd package), and dump the test
# registry TSV (via binfmt/qemu-user). Uses the shared musl cross toolchain
# from package-builder.
FROM --platform=$BUILDPLATFORM package-builder AS build-virtio-villain
RUN --mount=type=bind,from=src-virtio-villain,source=/,target=/pkg/virtio-villain/src \
    BUILD_CPIO=1 /pkg/Tools/build.sh pkg/virtio-villain
FROM scratch AS result-virtio-villain
COPY --from=build-virtio-villain --link /out/sysroot.cpio.gz /initramfs.cpio.gz
COPY --from=build-virtio-villain --link /out/tests.tsv /tests.tsv

# Build the Linux test kernels. One stage per kernel version; each stage
# bind-mounts its pinned source and reads its config from
# pkg/linux/<version>/<arch>.config (driven by $LINUX_VERSION exported via
# sysroots/linux-<version>/deps). The kernel result contains only the
# kernel images and final config; the initrd ships as its own artifact and
# is shared across all kernel versions. To add a new kernel line, add a
# matching `src-linux-<ver>` source stage above and a `build-linux-<ver>` /
# `result-linux-<ver>` pair here, then add a `COPY --from=result-linux-<ver>`
# line in the appropriate output stage.
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

FROM --platform=$BUILDPLATFORM package-builder AS build-linux-cca-v15
RUN --mount=type=bind,from=src-linux-cca-v15,source=/,target=/pkg/linux/src \
    /pkg/Tools/build.sh sysroots/linux-cca-v15
FROM scratch AS result-linux-cca-v15
COPY --from=build-linux-cca-v15 --link /sysroot/boot /

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

# Build TF-RMM for QEMU virt CCA tests. TF-RMM requires a bare-metal
# aarch64-none-elf GCC toolchain, so keep it separate from the musl package
# builder used for the Linux/sysroot artifacts.
FROM --platform=$BUILDPLATFORM ubuntu:24.04 AS rmm-builder
ARG TARGETARCH
ENV TARGETARCH=$TARGETARCH
COPY --link pkg/rmm/deps.sh /pkg/rmm/deps.sh
RUN /pkg/rmm/deps.sh
COPY --from=src-arm-gnu-toolchain-aarch64-none-elf --link /arm-gnu-toolchain-13.3.rel1-x86_64-aarch64-none-elf /opt/arm-gnu-toolchain
COPY --link pkg/rmm /pkg/rmm
ENV PATH="/opt/arm-gnu-toolchain/bin:${PATH}"

FROM --platform=$BUILDPLATFORM rmm-builder AS build-rmm-cca
RUN --mount=type=bind,from=src-tf-rmm-cca,source=/,target=/pkg/rmm/src \
    --mount=type=bind,from=src-tf-rmm-cpputest,source=/,target=/pkg/rmm/submodules/cpputest \
    --mount=type=bind,from=src-tf-rmm-libspdm,source=/,target=/pkg/rmm/submodules/libspdm \
    --mount=type=bind,from=src-tf-rmm-mbedtls,source=/,target=/pkg/rmm/submodules/mbedtls \
    --mount=type=bind,from=src-tf-rmm-minicoro,source=/,target=/pkg/rmm/submodules/minicoro \
    --mount=type=bind,from=src-tf-rmm-qcbor,source=/,target=/pkg/rmm/submodules/qcbor \
    --mount=type=bind,from=src-tf-rmm-spdm-emu,source=/,target=/pkg/rmm/submodules/spdm-emu \
    --mount=type=bind,from=src-tf-rmm-t-cose,source=/,target=/pkg/rmm/submodules/t_cose \
    RMM_FLAVOR=cca \
    RMM_CONFIG=qemu_virt_defcfg \
    RMM_SOURCE_REVISION=f00eac344b6f7c18abc6dad1948b07e9a82ff9f0 \
    SOURCE_DATE_EPOCH=1783958488 \
    /pkg/rmm/build.sh
FROM scratch AS result-rmm-cca
COPY --from=build-rmm-cca --link /out/ /

# Build TF-A for QEMU virt CCA tests, with TF-RMM included as RMM and Linux
# direct boot configured as a preloaded BL33.
FROM --platform=$BUILDPLATFORM rmm-builder AS tfa-builder
COPY --link pkg/tfa /pkg/tfa

FROM --platform=$BUILDPLATFORM tfa-builder AS build-tfa-cca
RUN --mount=type=bind,from=src-tfa-cca,source=/,target=/pkg/tfa/src \
    --mount=type=bind,from=result-rmm-cca,source=/,target=/pkg/tfa/rmm \
    TFA_FLAVOR=cca \
    TFA_SOURCE_REVISION=da738d5eae93af342fdc4995dd3c05acb4c9d757 \
    RMM_SOURCE_REVISION=f00eac344b6f7c18abc6dad1948b07e9a82ff9f0 \
    SOURCE_DATE_EPOCH=1779985789 \
    /pkg/tfa/build.sh
FROM scratch AS result-tfa-cca
COPY --from=build-tfa-cca --link /out/ /

# Build the architecture-neutral output set. The release workflow packs each
# top-level subdirectory into its own GitHub release artifact:
#   openvmm-deps/  -> openvmm-deps.<arch>.<release>.tar.gz
#   initrd/        -> openvmm-test-initrd.<arch>.<release>.tar.gz
#   linux-<kver>/  -> openvmm-test-linux-<kver>.<arch>.<release>.tar.gz
#   rmm-<rver>/    -> openvmm-test-rmm-<rver>.<arch>.<release>.tar.gz
#   tfa-<tver>/    -> openvmm-test-tfa-<tver>.<arch>.<release>.tar.gz
#   virtio-villain/ -> openvmm-test-virtio-villain.<arch>.<release>.tar.gz
FROM scratch AS output-base
COPY --from=result-dbgrd      --link / /openvmm-deps/
COPY --from=result-shell      --link / /openvmm-deps/
COPY --from=result-sdk        --link / /openvmm-deps/
COPY --from=result-petritools --link / /openvmm-deps/
COPY --from=result-initrd     --link /initrd /initrd/initrd
COPY --from=result-linux-6.1  --link / /linux-6.1/
COPY --from=result-linux-6.18 --link / /linux-6.18/
COPY --from=result-qemu       --link / /qemu/
# virtio-villain guest binaries. The cross-built `init` is packed into the
# initramfs and run under binfmt/qemu-user to dump tests.tsv.
COPY --from=result-virtio-villain --link / /virtio-villain/

FROM scratch AS output-aarch64
COPY --from=output-base       --link / /
COPY --from=result-linux-cca-v15 --link / /linux-cca-v15/
COPY --from=result-rmm-cca --link / /rmm-cca/
COPY --from=result-tfa-cca --link / /tfa-cca/

# Package the output directories into the exact archives uploaded by the
# release workflow. Keep packaging inside the Docker graph so PR and release
# builds use the same immutable inputs.
FROM --platform=$BUILDPLATFORM ubuntu:24.04 AS package-x86_64
ARG VERSION
COPY --from=output-base --link / /input/
RUN case "$VERSION" in \
        ""|*[!A-Za-z0-9._-]*) echo "invalid VERSION: $VERSION" >&2; exit 1 ;; \
    esac && \
    mkdir /package && \
    archive() { \
        name=$1; source=$2; \
        temporary="/tmp/${name%.gz}"; \
        tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner \
            -C "$source" -cf "$temporary" . && \
        gzip -n -c "$temporary" >"/package/$name" && \
        rm "$temporary"; \
    } && \
    archive "openvmm-deps.x86_64.$VERSION.tar.gz" /input/openvmm-deps && \
    archive "openvmm-test-initrd.x86_64.$VERSION.tar.gz" /input/initrd && \
    archive "openvmm-test-linux-6.1.x86_64.$VERSION.tar.gz" /input/linux-6.1 && \
    archive "openvmm-test-linux-6.18.x86_64.$VERSION.tar.gz" /input/linux-6.18 && \
    archive "qemu-linux-static.x86_64.$VERSION.tar.gz" /input/qemu && \
    archive "openvmm-test-virtio-villain.x86_64.$VERSION.tar.gz" /input/virtio-villain
FROM scratch AS packages-x86_64
COPY --from=package-x86_64 --link /package/ /

FROM --platform=$BUILDPLATFORM ubuntu:24.04 AS package-aarch64
ARG VERSION
COPY --from=output-aarch64 --link / /input/
RUN case "$VERSION" in \
        ""|*[!A-Za-z0-9._-]*) echo "invalid VERSION: $VERSION" >&2; exit 1 ;; \
    esac && \
    mkdir /package && \
    archive() { \
        name=$1; source=$2; \
        temporary="/tmp/${name%.gz}"; \
        tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner \
            -C "$source" -cf "$temporary" . && \
        gzip -n -c "$temporary" >"/package/$name" && \
        rm "$temporary"; \
    } && \
    archive "openvmm-deps.aarch64.$VERSION.tar.gz" /input/openvmm-deps && \
    archive "openvmm-test-initrd.aarch64.$VERSION.tar.gz" /input/initrd && \
    archive "openvmm-test-linux-6.1.aarch64.$VERSION.tar.gz" /input/linux-6.1 && \
    archive "openvmm-test-linux-6.18.aarch64.$VERSION.tar.gz" /input/linux-6.18 && \
    archive "openvmm-test-linux-cca-v15.aarch64.$VERSION.tar.gz" \
        /input/linux-cca-v15 && \
    archive "openvmm-test-rmm-cca.aarch64.$VERSION.tar.gz" /input/rmm-cca && \
    archive "openvmm-test-tfa-cca.aarch64.$VERSION.tar.gz" /input/tfa-cca && \
    archive "qemu-linux-static.aarch64.$VERSION.tar.gz" /input/qemu && \
    archive "openvmm-test-virtio-villain.aarch64.$VERSION.tar.gz" /input/virtio-villain
FROM scratch AS packages-aarch64
COPY --from=package-aarch64 --link /package/ /

# Keep the unpacked output as the default target for local `docker build`.
FROM scratch AS output
COPY --from=output-base       --link / /
