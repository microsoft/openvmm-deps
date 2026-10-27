# Linux Kernel Configuration

This directory contains the kernel configs and build script for the OpenVMM
test kernels. Petri and Incubator use them as guest kernels or nested test
hosts.

The build is structured to support multiple kernel lines side-by-side.
Today **6.1** (LTS), **6.18**, **cca-v15**, **snp-guest**, **mshv-host**, and
**mshv-test** ship; additional lines can be added purely additively (see
"Adding a new kernel version" below). The CCA line is Arm-only and ships for
`aarch64` only. The MSHV host and SNP guest lines ship for `x86_64`
only; MSHV test ships for both architectures. Each kernel is published as its
own GitHub release artifact
(`openvmm-test-linux-<version>.<arch>.<release>.tar.gz`) containing the
kernel images and final config. The initrd is shared across all kernels
and ships as its own `openvmm-test-initrd.<arch>.<release>.tar.gz`
artifact (so it isn't redundantly bundled into every kernel tarball).

## Layout

```
pkg/linux/
  build.sh                # Shared build script. Reads $LINUX_VERSION.
  patch.sh                # Applies <version>/patches/*.patch, if present.
  sync-configs-from-ci.sh # Pull resolved configs from CI artifacts.
  README.md               # This file.
  6.1/
    x86_64.config         # Kernel config for 6.1 / x86_64
    aarch64.config        # Kernel config for 6.1 / aarch64
  6.18/
    x86_64.config         # Kernel config for 6.18 / x86_64
    aarch64.config        # Kernel config for 6.18 / aarch64
  cca-v15/
    aarch64.config        # Unified CCA v15 test kernel / aarch64
  snp-guest/
    x86_64.config         # SEV-SNP guest kernel / x86_64
    required.config       # Settings the SNP guest boot needs
  mshv-host/
    x86_64.config         # MSHV root-partition host kernel / x86_64
    required.config       # Settings the Azure MSHV host needs
  mshv-test/
    x86_64.config         # Module-free mshv test root partition / x86_64
    aarch64.config        # Module-free mshv test root partition / aarch64
    required.config       # Built-in boot, network, and share drivers
    required.x86_64.config # x86_64 interrupt routing and console
    required.aarch64.config # ARM64 root support and QEMU virt platform
    patches/              # Root IO-APIC interrupt lifecycle fix
```

The version selection is driven by `$LINUX_VERSION`, which is exported by
the corresponding `sysroots/linux-<version>/deps` file (a single line of
the form `LINUX_VERSION=<version>`, picked up by `pkg/Tools/build.sh`'s env
handling). The Dockerfile pins one source-tree commit per kernel line
(`src-linux-6.1`, etc.) and bind-mounts the matching source into the
corresponding `build-linux-<version>` stage. Kernel flavors may share a source
stage while selecting different configs and patches; `mshv-test` reuses
`src-linux-mshv-host`.

A kernel line can also set these options in its deps file:

- `LINUX_SOURCE_REVISION` and `LINUX_SOURCE_EPOCH` make the build
  reproducible and write `manifest.txt` with the kernel release and hashes.
- `LINUX_MODULES=1` builds the modules and installs them, stripped and
  signed, under `lib/modules/<release>/` in the artifact. The build requires
  `CONFIG_MODULES=y`. The module signing key is generated per build and is
  not exported.

A line can carry patches in `pkg/linux/<version>/patches/`. `patch.sh`
applies them in filename order with no fuzz. The line's Dockerfile source
mount must be read-write (`rw`).

A line can also list settings in `pkg/linux/<version>/required.config` and
architecture-specific settings in `required.<arch>.config`. The build fails
if the resolved config does not contain every applicable setting.

The **cca-v15** line uses one exact `cca-host/v15` source commit and one union
configuration. The same image supports QEMU and FVP L1 hosts, nested Realm
guests, and the generic AArch64 TCG VFIO/P2P tests.

The **snp-guest** line is the L2 guest kernel for OpenVMM tests on MSHV with
SEV-SNP. It builds the Azure Linux tag
`rolling-lts/kata-uvm/6.18.52.mshv2` (commit `63eba05d`) in
[CBL-Mariner-Linux-Kernel](https://github.com/microsoft/CBL-Mariner-Linux-Kernel),
with a config based on `Microsoft/configs/x86/uvm_defconfig`, resolved by this
build. The tag includes the GHCB unregister, early x2APIC, and SNP AP
output-page fixes, so this line needs no local patches.

Boot-critical settings in `required.config` must stay built in, because the
artifact does not ship modules.

The **mshv-host** line is the L1 kernel for Azure Linux Dom0 test runners,
built from the Azure Linux tag `rolling-lts/kata/6.18.34.mshv4` (commit
[`e72bb1d3`](https://github.com/microsoft/CBL-Mariner-Linux-Kernel/commit/e72bb1d3ea93dea7891303c58c71e1a6d5ef6da0))
with its `Microsoft/configs/x86/mshv_defconfig`. The tag includes the SNP
interrupt injection policy and unmap-before-reclaim fixes.

The line sets `LINUX_MODULES=1`, so the artifact includes signed modules
under `lib/modules/<release>/`. Install the kernel and modules on the runner,
then generate its initramfs there. Each build generates a new module signing
key and embeds its certificate in the kernel, so the images and modules are
not byte-for-byte reproducible.

The package builder has no `pahole`, so the resolved config drops BTF
(`DEBUG_INFO_BTF`) and the options that depend on it. The MSHV tests do not
need BTF.

The **mshv-test** line is the module-free x86_64 and ARM64 mshv root kernel for
standalone Incubator and Petri tests that run mshv inside another hypervisor. It shares
the released `rolling-lts/kata/6.18.34.mshv4` source pin with `mshv-host`, but
starts from the module-free 6.18 test config and enables `CONFIG_MSHV_ROOT`.
EFI launch, PCIe, virtio block/network/console/vsock, and 9p are built in so
the existing shared test initrd can boot and connect Pipette without a module
tree. The ARM64 configuration is seeded from the 6.18 ARM64 test config
and enables MSHV root support with 4 KiB pages, the Hyper-V ARM64 IOMMU, and
the QEMU virt platform's GICv3/ITS, PSCI, generic PCI host, and PL011 console.
It targets the experimental standalone Incubator QEMU-TCG boot path; adding
this kernel does not enable registered ARM64 nested Petri tests or supply
the separate ARM64 EFI loader and hypervisor binaries.

This source retains the working EFI-launch path and restores the two-bank
partition-creation ABI needed by the public build-26100 hypervisor. The
IO-APIC patch affects x86_64 only: it ties root IO-APIC mappings to IRQ
activation/deactivation, releasing them before Linux recycles interrupt
vectors. Without it, stale mappings from
IRQ probing can prevent virtio devices from working during nested root boot.
An additional patch guards SEV-SNP-only helpers with their callers' feature
and architecture conditions so ARM64 builds retain `CONFIG_WERROR=y`.
The test line does not include the separate MSI lifecycle fix or other
development-branch changes. The installed Azure Dom0 `mshv-host` configuration
and module packaging are unchanged.

Build this kernel alone for either architecture with:

```bash
docker build --platform linux/amd64 --target result-linux-mshv-test \
  --output type=local,dest=out/linux-mshv-test-x86_64 .
docker build --platform linux/arm64 --target result-linux-mshv-test \
  --output type=local,dest=out/linux-mshv-test-aarch64 .
```

The architecture-specific package targets publish it as
`openvmm-test-linux-mshv-test.<arch>.<release>.tar.gz`. The archive contains
`vmlinux`, `bzImage` (x86_64) or `Image` (ARM64), the resolved `config`, and
`manifest.txt`; the initrd remains a separate shared artifact. PR builds
upload these archives in the `x86_64` and `aarch64` workflow artifacts,
including for draft PRs. Before merging a newly seeded config, extract and
commit the config resolved by CI.

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
   line to `output-base` (both architectures), `output-x86_64`, or
   `output-aarch64`.
3. Create `sysroots/linux-<ver>/deps` containing
   `LINUX_VERSION=<ver>` and `pkg/linux`.
4. Seed `pkg/linux/<ver>/{x86_64,aarch64}.config` by copying from the
   nearest existing version, then follow the "Updating a kernel config"
   procedure above to bootstrap the canonical config from the in-build
   `olddefconfig` output.
5. Add an `archive` line for the new version to the matching
   `package-x86_64` or `package-aarch64` stage in `Dockerfile`. The release
   job uploads every generated tarball, so no workflow change is required.
6. Run `python3 pkg/Tools/gen-cgmanifest.py` to refresh `cgmanifest.json`.

## Build

The `build.sh` script copies the chosen config to `.config`, runs
`make olddefconfig` (to resolve dependencies and fill in defaults), builds
the kernel, and exports the final `.config` alongside the kernel images.
See the top-level `README.md` for build instructions.
