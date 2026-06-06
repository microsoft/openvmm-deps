# Linux Kernel Configuration

This directory contains the kernel configs and build script for the OpenVMM
test kernels. These kernels are used by the petri test framework with Linux
direct boot (`Firmware::LinuxDirect`).

The build is structured to support multiple kernel lines side-by-side.
Today **6.1** (LTS) and **6.18** ship; additional lines can be added
purely additively (see "Adding a new kernel version" below). Each kernel
is published as its own GitHub release artifact
(`openvmm-test-linux-<version>.<arch>.<release>.tar.gz`) containing the
kernel images and final config. The initrd is shared across all kernels
and ships as its own `openvmm-test-initrd.<arch>.<release>.tar.gz`
artifact (so it isn't redundantly bundled into every kernel tarball).

## Layout

```
pkg/linux/
  build.sh                # Shared build script. Reads $LINUX_VERSION.
  sync-configs-from-ci.sh # Pull resolved configs from CI artifacts.
  README.md               # This file.
  6.1/
    x86_64.config         # Kernel config for 6.1 / x86_64
    aarch64.config        # Kernel config for 6.1 / aarch64
  6.18/
    x86_64.config         # Kernel config for 6.18 / x86_64
    aarch64.config        # Kernel config for 6.18 / aarch64
```

The version selection is driven by `$LINUX_VERSION`, which is exported by
the corresponding `sysroots/linux-<version>/deps` file (a single line of
the form `LINUX_VERSION=<version>`, picked up by `pkg/Tools/build.sh`'s env
handling). The Dockerfile pins one source-tree commit per kernel line
(`src-linux-6.1`, etc.) and bind-mounts the matching source into the
corresponding `build-linux-<version>` stage.

## Updating a kernel config

The build runs `make olddefconfig` inside the container using the musl
cross-compiler toolchain. To ensure the committed config exactly matches
what the build uses, always extract the final config from the build output
rather than running `olddefconfig` locally (which uses your host compiler
and produces toolchain-dependent noise in the diff).

### Via CI (recommended)

The easiest way to update configs across all architectures and kernel
versions at once is to let CI do the build and then pull the resolved
configs back:

1. Edit the config file(s) directly (e.g., change `# CONFIG_FOO is not set`
   to `CONFIG_FOO=y`) under `pkg/linux/<version>/`.

2. Commit, push your branch, and wait for the CI build to complete.

3. Run the sync script to download the final configs from the CI artifacts:

   ```bash
   # Uses the latest CI run for the current branch:
   pkg/linux/sync-configs-from-ci.sh

   # Or specify a run ID:
   pkg/linux/sync-configs-from-ci.sh 12345
   ```

4. Review the resolved changes and push:

   ```bash
   git diff pkg/linux/
   git add pkg/linux/ && git commit -m "sync resolved kernel configs from CI" && git push
   ```

### Locally (single arch/version)

If you prefer to build locally (e.g., for a quick iteration on one combo):

1. Edit the config file directly (e.g., change `# CONFIG_FOO is not set` to
   `CONFIG_FOO=y`) under `pkg/linux/<version>/`.

2. Build the kernel for the target architecture:

   ```bash
   # For x86_64 / 6.1:
   docker build --platform linux/amd64 --target result-linux-6.1 \
     --output type=local,dest=out/linux-6.1 -f Dockerfile .

   # For aarch64 / 6.1:
   docker build --platform linux/arm64 --target result-linux-6.1 \
     --output type=local,dest=out/linux-6.1 -f Dockerfile .
   ```

3. Copy the final config (produced by `olddefconfig` inside the build) back
   into the source tree:

   ```bash
   # For x86_64 / 6.1:
   cp out/linux-6.1/config pkg/linux/6.1/x86_64.config

   # For aarch64 / 6.1:
   cp out/linux-6.1/config pkg/linux/6.1/aarch64.config
   ```

4. Review the diff, commit, and push.

## Adding a new kernel version

> **Important:** before merging a new kernel version (or bumping an
> existing one's pinned commit across a major LTS boundary), always run
> the bootstrap below and commit the resulting `olddefconfig`-resolved
> configs. The seeded configs are starting points only — they may carry
> stale options, and `CONFIG_WERROR=y` means new compiler warnings under
> the musl GCC toolchain will become hard build failures if unaddressed.

1. Look up the latest commit on the desired LTS branch in
   `gregkh/linux` (e.g. `linux-6.12.y`).
2. In `Dockerfile`, add a new `src-linux-<ver>` stage pinning that commit,
   and a `build-linux-<ver>` / `result-linux-<ver>` pair modeled on the
   existing 6.1 ones. Add a corresponding `COPY --from=result-linux-<ver>`
   line in the final `output` stage.
3. Create `sysroots/linux-<ver>/deps` containing
   `LINUX_VERSION=<ver>` and `pkg/linux`.
4. Seed `pkg/linux/<ver>/{x86_64,aarch64}.config` by copying from the
   nearest existing version, then follow the "Updating a kernel config"
   procedure above to bootstrap the canonical config from the in-build
   `olddefconfig` output.
5. Add the new version to the `KERNELS` list in the `release` job in
   `.github/workflows/build.yml` (the gh-release upload picks up tarballs
   by glob, so no further workflow changes are required).
6. Run `python3 pkg/Tools/gen-cgmanifest.py` to refresh `cgmanifest.json`.

## Build

The `build.sh` script copies the chosen config to `.config`, runs
`make olddefconfig` (to resolve dependencies and fill in defaults), builds
the kernel, and exports the final `.config` alongside the kernel images.
See the top-level `README.md` for build instructions.
