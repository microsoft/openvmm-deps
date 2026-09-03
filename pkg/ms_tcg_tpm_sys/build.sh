#!/bin/bash

# Build the TCG TPM archives by invoking `ms-tcg-tpm-sys`'s own `build.rs`
# via cargo, so the CMake configuration, crypto backend selection, and
# compile flags all live in the upstream wrapper crate -- not duplicated
# here.
#
# `cargo check` is sufficient as it still runs the build script to produce
# the archives as a side-effect.
#
# The crate links against exactly one crypto backend at a time, so it gets
# built once per backend. Consumers pick one by pointing `TCG_TPM_LIB_DIR`
# at the matching directory.

# Build the TPM against one crypto backend and install the result into
# `$SYSROOT/<name>/lib`.
build_backend() (
    set -e

    cd "$SRCDIR"

    name="$1"
    shift

    # Keep the backends in separate target directories so their archives
    # stay trivially distinguishable below.
    CARGO_TARGET_DIR="$BUILDDIR/target-$name"
    export CARGO_TARGET_DIR
    cargo check --release --locked -p ms-tcg-tpm-sys --no-default-features "$@"

    # `build.rs` collects the TPM library's own archives under
    # `OUT_DIR/lib`. Ship those rather than the symbol-prefixed copies in
    # `OUT_DIR`, since consumers pointed at `TCG_TPM_LIB_DIR` run the
    # prefixing pass themselves.
    libdir=$(find "$CARGO_TARGET_DIR/$CARGO_BUILD_TARGET/release/build" \
        -path '*/ms-tcg-tpm-sys-*/out/lib' -print -quit)
    if [ -z "$libdir" ]; then
        echo "no TPM archives were built for $name" >&2
        exit 1
    fi

    install -d "$SYSROOT/$name/lib"
    install -m 644 "$libdir"/libTpm_*.a "$SYSROOT/$name/lib/"
)

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    # Where `pkg/symcrypt` installed its static build.
    export SYMCRYPT_INCLUDE_DIR="${SYMCRYPT_INCLUDE_DIR:-$SYSROOT/include}"
    export SYMCRYPT_LIB_DIR="${SYMCRYPT_LIB_DIR:-$SYSROOT/lib}"

    build_backend tcg-tpm-openssl --features openssl
    # build_backend tcg-tpm-symcrypt --features symcrypt
fi
