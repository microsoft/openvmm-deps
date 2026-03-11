# Linux Kernel Configuration

This directory contains the kernel configs and build script for the OpenVMM
test kernels. These kernels are used by the petri test framework with Linux
direct boot (`Firmware::LinuxDirect`).

## Files

- `x86_64.config` — Kernel config for x86_64 (kernel 6.1.74)
- `aarch64.config` — Kernel config for aarch64 (kernel 6.1.74)
- `build.sh` — Build script invoked by the Docker build

## Updating the kernel configs

The build runs `make olddefconfig` inside the container using the musl
cross-compiler toolchain. To ensure the committed config exactly matches
what the build uses, always extract the final config from the build output
rather than running `olddefconfig` locally (which uses your host compiler
and produces toolchain-dependent noise in the diff).

1. Edit the config file directly (e.g., change `# CONFIG_FOO is not set` to
   `CONFIG_FOO=y`).

2. Build the kernel for the target architecture:

   ```bash
   # For x86_64:
   docker build --platform linux/amd64 --target result-linux \
     --output type=local,dest=out/linux -f Dockerfile .

   # For aarch64:
   docker build --platform linux/arm64 --target result-linux \
     --output type=local,dest=out/linux -f Dockerfile .
   ```

3. Copy the final config (produced by `olddefconfig` inside the build) back
   into the source tree:

   ```bash
   # For x86_64:
   cp out/linux/config pkg/linux/x86_64.config

   # For aarch64:
   cp out/linux/config pkg/linux/aarch64.config
   ```

4. Review the diff, commit, and push.

## Build

The `build.sh` script copies the config to `.config`, runs
`make olddefconfig` (to resolve dependencies and fill in defaults), builds
the kernel, and exports the final `.config` alongside the kernel images.
See the top-level `README.md` for build instructions.
