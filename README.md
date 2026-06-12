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
docker build --platform x86_64 --output type=local,dest=out .
docker build --platform aarch64 --output type=local,dest=out .
```

The output directory is laid out so that each top-level subdirectory maps
to one GitHub release artifact:

```
out/
  openvmm-deps/        sdk + dbgrd + shell + petritools sysroots
  initrd/              shared busybox-based test rootfs (cpio.gz)
  linux-6.1/           vmlinux (stripped) + bzImage/Image + config
  linux-6.1-debug/     vmlinux.debug (DWARF5 symbols for 6.1)
  linux-6.18/          vmlinux (stripped) + bzImage/Image + config
  linux-6.18-debug/    vmlinux.debug (DWARF5 symbols for 6.18)
  qemu/                qemu-system-aarch64, qemu-system-x86_64
```

The release pipeline packs each of these into its own tarball:

| Artifact                                              | Contents                              |
| ----------------------------------------------------- | ------------------------------------- |
| `openvmm-deps.<arch>.<ver>.tar.gz`                    | sdk + dbgrd + shell + petritools      |
| `openvmm-test-initrd.<arch>.<ver>.tar.gz`             | shared initrd (used with any kernel)  |
| `openvmm-test-linux-6.1.<arch>.<ver>.tar.gz`          | 6.1 LTS kernel images + final config  |
| `openvmm-test-linux-6.1-debug.<arch>.<ver>.tar.gz`    | 6.1 `vmlinux.debug` symbol file       |
| `openvmm-test-linux-6.18.<arch>.<ver>.tar.gz`         | 6.18 kernel images + final config     |
| `openvmm-test-linux-6.18-debug.<arch>.<ver>.tar.gz`   | 6.18 `vmlinux.debug` symbol file      |
| `openvmm-test-virtio-win.<ver>.tar.gz`                | virtio-win NetKVM drivers (all OS/arch)|
| `qemu-linux-static.<arch>.<ver>.tar.gz`                | static QEMU system emulators (TCG)    |

The `openvmm-deps` tarball no longer contains a kernel; consumers that
need a Linux-direct boot kernel (e.g. petri's `Firmware::LinuxDirect`)
should fetch the matching `openvmm-test-linux-<version>` artifact for
the kernel and `openvmm-test-initrd` for the userland (the same initrd
is used with every kernel version). Additional kernel lines may be
added as separate `openvmm-test-linux-<version>` artifacts in future
releases.

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
docker build -f Dockerfile.virtio-win --output type=local,dest=out .
```

The output preserves the ISO's directory layout (e.g.
`NetKVM/2k22/amd64/`, `NetKVM/2k25/ARM64/`). Currently only NetKVM
drivers are extracted; to add more driver families, extend the `grep`
filter in `Dockerfile.virtio-win`.

The ISO is mirrored to the
[`virtio-iso-v1`](https://github.com/microsoft/openvmm-deps/releases/tag/virtio-iso-v1)
GitHub release, pinned by sha256 checksum.
