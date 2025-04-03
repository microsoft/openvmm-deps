# syntax=docker/dockerfile:1

ARG HOST_IMAGE=mcr.microsoft.com/cbl-mariner/base/core:2.0
ARG TARGET_IMAGE=mcr.microsoft.com/cbl-mariner/base/core:2.0

# Build the musl toolchain
FROM --platform=$BUILDPLATFORM $HOST_IMAGE AS cross-builder
COPY /cross/deps.sh /cross/
RUN /cross/deps.sh
# Download sources. build.sh can do this for us, but then they won't be cached.
# Plus, this allows us to validate a SHA256 checksum instead of just SHA1.
ADD --checksum=sha256:ab66fc2d1c3ec0359b8e08843c9f33b63e8707efdff5e4cc5c200eae24722cbf --link https://ftpmirror.gnu.org/gnu/binutils/binutils-2.33.1.tar.xz sources/
ADD --checksum=sha256:75d5d255a2a273b6e651f82eecfabf6cbcd8eaeae70e86b417384c8f4a58d8d3 --link https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=3d5db9ebe860 /sources/config.sub
ADD --checksum=sha256:a6e21868ead545cf87f0c01f84276e4b5281d672098591c1c896241f09363478 --link https://ftpmirror.gnu.org/gnu/gcc/gcc-11.5.0/gcc-11.5.0.tar.xz /sources/
ADD --checksum=sha256:5275bb04f4863a13516b2f39392ac5e272f5e1bb8057b18aec1c9b79d73d8fb2 --link https://ftpmirror.gnu.org/gnu/gmp/gmp-6.1.2.tar.bz2 /sources/
ADD --checksum=sha256:dc7abf734487553644258a3822cfd429d74656749e309f2b25f09f4282e05588 --link https://ftp.barfooze.de/pub/sabotage/tarballs/linux-headers-4.19.88-2.tar.xz /sources/
ADD --checksum=sha256:6985c538143c1208dcb1ac42cedad6ff52e267b47e5f970183a3e75125b43c2e --link https://ftpmirror.gnu.org/gnu/mpc/mpc-1.1.0.tar.gz /sources/
ADD --checksum=sha256:c05e3f02d09e0e9019384cdd58e0f19c64e6db1fd6f5ecf77b4b1c61ca253acc --link https://ftpmirror.gnu.org/gnu/mpfr/mpfr-4.0.2.tar.bz2 /sources/
ADD --checksum=sha256:a9a118bbe84d8764da0ea0d28b3ab3fae8477fc7e4085d90102b8596fc7c75e4 --link https://musl.libc.org/releases/musl-1.2.5.tar.gz /sources/
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
COPY --link src /src
COPY --link pkg /pkg
COPY --link sysroots /sysroots
ENV PATH="${PATH}:/opt/cross/bin"
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

# Build the sdk.
#
# Note that this pulls from the cross compiler and doesn't use the target
# builder.
FROM --platform=$BUILDPLATFORM package-builder AS build-sdk
RUN ln -s /opt/cross/*-linux-musl /sysroot
RUN /pkg/Tools/build.sh sysroots/sdk
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

# Build the Linux test package.
FROM --platform=$BUILDPLATFORM package-builder AS build-linux
RUN /pkg/Tools/build.sh sysroots/linux
FROM scratch AS result-linux
COPY --from=build-linux --link /sysroot/boot /
COPY --from=result-initrd --link / /

FROM --platform=$BUILDPLATFORM package-builder AS result-libunwind
RUN /pkg/Tools/build.sh pkg/libunwind
RUN find /sysroot

# Build the output.
FROM scratch AS output
COPY --from=result-dbgrd --link / /
COPY --from=result-shell --link / /
COPY --from=result-sdk --link / /
COPY --from=result-linux --link / /
