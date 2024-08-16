#!/bin/bash

set -e

# Convert the Go/Docker architecture to the gcc toolchain architecture.
case $TARGETARCH in
    amd64) ARCH=x86_64 ;;
    arm64) ARCH=aarch64 ;;
    *) >&2 echo "Unknown architecture: $TARGETARCH" && exit 1 ;;
esac

export ARCH
export TOOLSDIR="/pkg/Tools"
export SYSROOT="${SYSROOT:-/sysroot}"
export OUTPUTDIR="${OUTPUTDIR:-/out}"

mkdir -p "$SYSROOT" "$OUTPUTDIR"

export CMAKE_TOOLCHAIN_FILE="$TOOLSDIR/cmake.$ARCH.toolchain"

pkgs=()
deps=()
declare -A pkg_added dep_added
function get-deps {
    local input
    while read input; do
        if [[ $input == */* ]]; then
            if [[ ! ${pkg_added[$input]+_} ]]; then
                pkg_added[$input]=1
                [ -d "$input" ] || {
                    >&2 echo "package directory not found: $input"
                    exit 1
                }
                if [[ -f "$input/deps" ]]; then
                    get-deps <"$input/deps"
                fi
                if [[ -f "$input/deps.$ARCH" ]]; then
                    get-deps <"$input/deps.$ARCH"
                fi
                echo "package: $input"
                pkgs+=("$input")
            fi
        elif [[ $input == *=* ]]; then
            # Set the provided environment variable for package builds.
            env="$(eval echo \"${input?}\")"
            echo "env: $env"
            export "$env"
        elif [[ ! ${dep_added[$input]+_} ]] ; then
            echo "dep: $input"
            dep_added[$input]=1
            deps+=("$input")
        else
          echo "Ignored: $input"
        fi
    done < <(sed -E 's/^([^#]*)(#.*)?/\1/' | grep -v '^\s*$') # Ignore comments and blank lines.
}

get-deps <<EOF
$1
EOF

if [ -n "$BUILD_BASE" ]; then
    # Just prepare the base image.
    "$TOOLSDIR/base.sh" "${deps[@]}"
    exit
fi

# Ensure build dependencies are all installed.
"$TOOLSDIR/deps.sh"

for pkg in "${pkgs[@]}"; do
    PKGDIR=$(realpath "$pkg")
    export PKGDIR
    export SRCDIR="$PKGDIR/src"
    export BUILDDIR="/work/$pkg"

    if [[ -f "$PKGDIR/patch.sh" && ! -f "$PKGDIR/.patched" ]]; then
        (
            cd "$SRCDIR"
            "$PKGDIR/patch.sh"
            touch "$PKGDIR/.patched"
        )
    fi

    if [[ -f "$PKGDIR/build.sh" && ! -f "$BUILDDIR/.built" ]]; then
        (
            mkdir -p "$BUILDDIR"
            cd "$BUILDDIR"
            bash "$PKGDIR/build.sh"
            touch "$BUILDDIR/.built"
        )
    fi
done

# Remove package indexes and other cruft.
rm -rf "$SYSROOT/var/cache/tdnf" "$SYSROOT/var/lib/rpm" "$SYSROOT/usr/share/man" "$SYSROOT/usr/share/doc"

if [ -z "$BUILD_CPIO" ]; then
    tar -zcf "${OUTPUTDIR}/sysroot.tar.gz" -C "$SYSROOT" --exclude ./dev --exclude ./proc .
else
    bsdtar -zcf "${OUTPUTDIR}/sysroot.cpio.gz" -C "$SYSROOT" --format newc .
fi
