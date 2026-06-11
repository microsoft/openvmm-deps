#!/bin/sh

set -e

# Build libtpm.a by invoking `ms-tpm-20-ref-rs`'s own `build.rs` via
# cargo, so the C source list, overrides, compile flags, and defines
# all live in the upstream wrapper crate -- not duplicated here.
#
# `cargo check` is sufficient as it still runs the build script to
# produce libtpm.a as a side-effect.
cd "$SRCDIR"
cargo check --release --locked

# `build.rs` writes libtpm.a under `OUT_DIR/ms-tpm-20-ref/`.
LIBTPM=$(find "$CARGO_TARGET_DIR/$CARGO_BUILD_TARGET/release/build" -path '*/ms-tpm-20-ref-*/out/ms-tpm-20-ref/libtpm.a' -print -quit)

install -d "$SYSROOT/tpm-oss-openssl/lib"
install -m 644 "$LIBTPM" "$SYSROOT/tpm-oss-openssl/lib/libtpm.a"
