# Copilot Instructions for openvmm-deps

## Architecture

This repo is a Docker-based build system that produces cross-compiled binary
dependencies for [OpenVMM](https://github.com/microsoft/openvmm). The entire
build runs inside a multi-stage `Dockerfile`; there is no host-side build
command beyond `docker build`.

### Key concepts

- **Sysroots** (`sysroots/<name>/deps`) define build targets. Each `deps` file
  lists packages (as `pkg/<name>` paths) and distro packages (bare names
  installed via `tdnf`). Lines of the form `KEY=VALUE` are exported as
  environment variables during the build.
- **Packages** (`pkg/<name>/`) contain a `build.sh` that compiles one component
  from source using the musl cross-compiler toolchain. They may also have
  `patch.sh`, architecture-specific `deps.<arch>` files, and source mounted via
  Docker bind mounts.
- **`pkg/Tools/build.sh`** is the build driver. It recursively resolves `deps`
  files, exports `KEY=VALUE` lines as env vars, installs distro deps via
  `base.sh`/`tdnf`, then iterates over packages and runs each `build.sh`.
- **Cross toolchain** (`cross/`) builds a musl-cross-make GCC toolchain
  (x86_64 and aarch64 targets). Packages use `$ARCH-linux-musl-` as the cross
  prefix.
- **Output formats**: sysroots produce either a `.tar.gz`, `.cpio.gz`
  (initrd/shell/dbgrd), or `.erofs` (petritools) depending on `BUILD_CPIO` /
  `BUILD_EROFS` env vars.

### Build targets (Dockerfile stages)

| Target | Purpose |
|--------|---------|
| `result-sdk` | Static libs (openssl, symcrypt, libunwind) for linking openvmm |
| `result-dbgrd` | Full debug rootfs (gdb, strace, htop) |
| `result-shell` | Minimal busybox shell rootfs |
| `result-initrd` | Shared test initrd for Linux-direct boot |
| `result-petritools` | Performance tools rootfs (fio, iperf3) as EROFS |
| `result-linux-6.1` | Linux 6.1 LTS kernel images |
| `result-linux-6.18` | Linux 6.18 kernel images |

## Build Commands

```bash
# Full build (both architectures)
docker build --platform x86_64 --output type=local,dest=out .
docker build --platform aarch64 --output type=local,dest=out .

# Single target (faster iteration)
docker build --platform x86_64 --target result-linux-6.1 \
  --output type=local,dest=out/linux-6.1 .

# Cross-compilation requires qemu-user-static
apt install qemu-user-static
```

There is no test suite. CI validates the build completes and that
`cgmanifest.json` is in sync:

```bash
python3 pkg/Tools/gen-cgmanifest.py --check
```

## Conventions

### Adding/modifying packages

- Each package lives in `pkg/<name>/` with a `build.sh` that uses `$SRCDIR`,
  `$BUILDDIR`, `$SYSROOT`, `$ARCH`, and `$PKGDIR` environment variables.
- Source code is bind-mounted (not copied) into the Docker build via
  `--mount=type=bind,from=src-<name>` in the Dockerfile.
- Source tarballs/repos are pinned by SHA256 checksum or commit hash in the
  Dockerfile. Each mirrored source must have a `# upstream:` comment recording
  the canonical URL.

### Kernel configs

- Configs live at `pkg/linux/<version>/<arch>.config`.
- Never edit configs outside the container — always extract the post-
  `olddefconfig` result from the build output (see `pkg/linux/README.md`).
- `CONFIG_WERROR=y` is enabled; new compiler warnings become build failures.

### Component Governance

- Run `python3 pkg/Tools/gen-cgmanifest.py` after modifying Dockerfile `ADD`
  lines. CI enforces the manifest stays in sync.

### Adding a new kernel version

1. Pin the source commit in Dockerfile as a `src-linux-<ver>` stage.
2. Add `build-linux-<ver>` / `result-linux-<ver>` stages and a `COPY` in the
   `output` stage.
3. Create `sysroots/linux-<ver>/deps` with `LINUX_VERSION=<ver>` and `pkg/linux`.
4. Seed configs from the nearest version, then bootstrap via the build.
5. Add to the `KERNELS` list in `.github/workflows/build.yml`.
6. Regenerate `cgmanifest.json`.
