This repo contains a small build system for openvmm dependencies.

To use, first clone this repo:
```bash
git clone https://github.com/microsoft/openvmm-deps
```

If you are cross-compiling you will need qemu-user-static:
```bash
apt install qemu-user-static
```

Then build the Dockerfile to produce the results for the desired architecture:

```bash
docker build --platform x86_64 --target output-x86_64 --output type=local,dest=out .
docker build --platform aarch64 --target output-aarch64 --output type=local,dest=out .
```

The output directory is laid out so that each top-level subdirectory maps
to one GitHub release artifact:

```
out/
  openvmm-deps/        sdk + dbgrd + shell + petritools sysroots
  initrd/              shared busybox-based test rootfs (cpio.gz)
  linux-6.1/           vmlinux, bzImage/Image, config (kernel only)
  linux-6.18/          vmlinux, bzImage/Image, config (kernel only)
  linux-cca-v15/         vmlinux, Image, config, manifest (aarch64 output only)
  linux-snp-guest/     vmlinux, bzImage, config, manifest (x86_64 output only)
  linux-mshv-host/     vmlinux, bzImage, config, manifest, lib/modules (x86_64 output only)
  linux-mshv-test/     vmlinux, bzImage/Image, config, manifest
  rmm-cca/             rmm.img and debug artifacts (aarch64 output only)
  tfa-cca/             flash.bin and debug artifacts (aarch64 output only)
  sbsa-mshv/           paired TF-A/UEFI flash images and manifest (aarch64 output only)
  qemu/                qemu-system-aarch64, qemu-system-x86_64
  virtio-villain/      initramfs.cpio.gz, tests.tsv
```

The release pipeline packs each of these into its own tarball:

| Artifact                                              | Contents                              |
| ----------------------------------------------------- | ------------------------------------- |
| `openvmm-deps.<arch>.<ver>.tar.gz`                    | sdk + dbgrd + shell + petritools      |
| `openvmm-test-initrd.<arch>.<ver>.tar.gz`             | shared initrd (used with any kernel)  |
| `openvmm-test-linux-6.1.<arch>.<ver>.tar.gz`          | 6.1 LTS kernel images + final config  |
| `openvmm-test-linux-6.18.<arch>.<ver>.tar.gz`         | 6.18 kernel images + final config     |
| `openvmm-test-linux-cca-v15.aarch64.<ver>.tar.gz`         | unified v15 Arm CCA host, guest, and VFIO/P2P test kernel |
| `openvmm-test-linux-snp-guest.x86_64.<ver>.tar.gz`    | SEV-SNP guest kernel for OpenVMM MSHV tests |
| `openvmm-test-linux-mshv-host.x86_64.<ver>.tar.gz`    | MSHV root-partition host kernel and modules |
| `openvmm-test-linux-mshv-test.<arch>.<ver>.tar.gz`    | Module-free mshv root kernel for Incubator and nested Petri tests |
| `openvmm-test-rmm-cca.aarch64.<ver>.tar.gz`             | TF-RMM firmware for QEMU virt CCA tests |
| `openvmm-test-tfa-cca.aarch64.<ver>.tar.gz`             | TF-A firmware for Linux-direct QEMU virt CCA tests |
| `openvmm-test-sbsa-mshv.aarch64.<ver>.tar.gz`          | Paired TF-A/UEFI flash for QEMU sbsa-ref MSHV Incubator |
| `openvmm-test-virtio-win.<ver>.tar.gz`                | virtio-win NetKVM and viostor drivers (all OS/arch) |
| `openvmm-test-virtio-villain.<arch>.<ver>.tar.gz`     | virtio-villain guest initramfs + `tests.tsv` |
| `qemu-linux-static.<arch>.<ver>.tar.gz`                | static QEMU system emulators (TCG)    |

Build release-shaped archives directly from the Docker graph:

```bash
docker buildx build \
  --platform aarch64 \
  --target packages-aarch64 \
  --build-arg VERSION=<version> \
  --output type=local,dest=out/package \
  .
```

The default final stage remains the unpacked `output` layout, which contains
only artifacts built for both architectures. Use `output-x86_64` or
`output-aarch64` to include architecture-specific artifacts. Select a
`packages-x86_64` or `packages-aarch64` target only when release-shaped
archives are required.

The `openvmm-deps` tarball no longer contains a kernel; consumers that
need a Linux-direct boot kernel (e.g. petri's `Firmware::LinuxDirect`)
should fetch the matching `openvmm-test-linux-<version>` artifact for
the kernel and `openvmm-test-initrd` for the userland (the same initrd
is used with every kernel version). Additional kernel lines may be
added as separate `openvmm-test-linux-<version>` artifacts in future
releases.

The ARM64 MSHV Incubator firmware is built from pinned TF-A, EDK2, and
edk2-platforms sources, including the temporary HvLoader memory-attribute
workaround. It is development/test firmware, not a production image.
See [pkg/sbsa-mshv/README.md](pkg/sbsa-mshv/README.md) for source pins,
patches, flash layout, and build targets. Hyper-V and its loader payloads
are separate inputs and are not included in this artifact.

For local testing, you can:
- Copy `out/openvmm-deps/sysroot.tar.gz` to `<openvmm src>/.packages/openvmm-deps/`
- untar the file to overwrite the libs
- rebuild openvmm

To build only one target (e.g. just a kernel) use `--target`:

```bash
docker build --platform x86_64 --target result-linux-6.1 \
  --output type=local,dest=out/linux-6.1 .
```

## virtio-win drivers

A separate `Dockerfile.virtio-win` extracts Windows virtio drivers from
the [virtio-win](https://github.com/virtio-win/virtio-win-pkg-scripts)
ISO. This build is architecture-independent (the ISO contains Windows PE
binaries for multiple guest architectures) and runs separately from the
main cross-compilation pipeline.

```bash
docker buildx build \
  -f Dockerfile.virtio-win \
  --output type=local,dest=out .
```

This output preserves the ISO's directory layout (e.g.
`NetKVM/2k22/amd64/`, `NetKVM/2k25/ARM64/`, and `viostor/2k22/amd64/`).
To build the release-shaped archive instead:

```bash
docker buildx build \
  -f Dockerfile.virtio-win \
  --target packages \
  --build-arg VERSION=<version> \
  --output type=local,dest=out .
```

NetKVM (virtio-net) and viostor (virtio-blk) drivers are extracted for all
OS versions and architectures present in the ISO. PDB and README files are
excluded. The build checks that both drivers include nonempty INF, SYS, and
CAT files for Windows Server 2022 x64. To add more driver families, extend
the `grep` filter in `Dockerfile.virtio-win`.

The ISO is mirrored to the
[`virtio-iso-v1`](https://github.com/microsoft/openvmm-deps/releases/tag/virtio-iso-v1)
GitHub release, pinned by sha256 checksum.
