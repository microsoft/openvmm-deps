#!/bin/bash
#
# Generate SPDX SBOMs for each shipped sysroot artifact using syft.
#
# Each artifact contains /var/lib/rpm (the RPM database), which syft reads
# natively to enumerate installed packages. SPDX output is the standard
# SBOM format consumed by sbom-tool, Component Detection, and Defender.
#
# Inputs:
#   $1  Directory containing the build outputs (e.g. dbgrd.cpio.gz, ...)
#   $2  Directory to write the *.spdx.json files into
#
# Requires: syft on PATH (single Go binary).

set -euo pipefail

INDIR="${1:?usage: gen-sboms.sh <inputs-dir> <outputs-dir>}"
OUTDIR="${2:?usage: gen-sboms.sh <inputs-dir> <outputs-dir>}"

mkdir -p "$OUTDIR"

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

scan() {
    local artifact="$1"
    local name="$2"
    local extracted="$SCRATCH/$name"

    mkdir -p "$extracted"
    case "$artifact" in
        *.cpio.gz)
            gunzip -c "$artifact" | (cd "$extracted" && cpio -idm 2>/dev/null)
            ;;
        *.tar.gz|*.tgz)
            tar -xzf "$artifact" -C "$extracted"
            ;;
        initrd)
            # initrd is a gzipped cpio archive (see Dockerfile build-initrd stage).
            gunzip -c "$artifact" | (cd "$extracted" && cpio -idm 2>/dev/null)
            ;;
        *)
            echo "Skipping unsupported artifact format: $artifact" >&2
            return
            ;;
    esac

    if [[ ! -d "$extracted/var/lib/rpm" ]]; then
        echo "Skipping $name: no RPM database found inside artifact" >&2
        return
    fi

    echo "Scanning $name..."
    syft scan "dir:$extracted" \
        --source-name "$name" \
        -o "spdx-json=$OUTDIR/$name.spdx.json"
}

shopt -s nullglob
for artifact in "$INDIR"/*.cpio.gz "$INDIR"/*.tar.gz "$INDIR"/initrd; do
    [ -e "$artifact" ] || continue
    name="$(basename "$artifact")"
    name="${name%.cpio.gz}"
    name="${name%.tar.gz}"
    scan "$artifact" "$name"
done

echo "Generated SBOMs:"
ls -la "$OUTDIR"
