#!/bin/sh
# Download the final kernel configs from a CI run and copy them into the
# source tree.  This saves you from running the docker build locally for
# all 4 arch/version combos.
#
# Usage:
#   pkg/linux/sync-configs-from-ci.sh [<run-id>]
#
# If <run-id> is omitted, uses the latest workflow run for the current branch.
# Requires the GitHub CLI (`gh`).

set -e

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

ARCHES="x86_64 aarch64"

run_id="${1:-}"

if [ -z "$run_id" ]; then
    branch="$(git rev-parse --abbrev-ref HEAD)"
    echo "Looking up latest CI run for branch '$branch'..."
    run_id="$(gh run list --workflow=build.yml --branch="$branch" --limit=1 --json databaseId --jq '.[0].databaseId')"
    if [ -z "$run_id" ] || [ "$run_id" = "null" ]; then
        echo >&2 "No CI runs found for branch '$branch'."
        exit 1
    fi
    echo "Using run $run_id"
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

for arch in $ARCHES; do
    echo "Downloading '$arch' artifact from run $run_id..."
    gh run download "$run_id" --name "$arch" --dir "$tmpdir/$arch"
done

# Discover kernel versions from the downloaded artifact.
for arch in $ARCHES; do
    for config in "$tmpdir/$arch"/linux-*/config; do
        [ -f "$config" ] || continue
        kver="$(basename "$(dirname "$config")")"
        kver="${kver#linux-}"
        dst="pkg/linux/$kver/$arch.config"
        mkdir -p "$(dirname "$dst")"
        cp "$config" "$dst"
        echo "Updated $dst"
    done
done

echo "Done. Review changes with: git diff pkg/linux/"
