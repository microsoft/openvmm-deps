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
  linux-6.1/           vmlinux, bzImage/Image, config, initrd
```

The release pipeline packs each of these into its own tarball:

| Artifact                                              | Contents                              |
| ----------------------------------------------------- | ------------------------------------- |
| `openvmm-deps.<arch>.<ver>.tar.gz`                    | sdk + dbgrd + shell + petritools      |
| `openvmm-test-linux-6.1.<arch>.<ver>.tar.gz`          | 6.1 LTS kernel + matching initrd      |

The `openvmm-deps` tarball no longer contains a kernel; consumers that
need a Linux-direct boot kernel (e.g. petri's `Firmware::LinuxDirect`)
should fetch the matching `openvmm-test-linux-<version>` artifact instead.
Additional LTS kernel lines may be added as separate
`openvmm-test-linux-<version>` artifacts in future releases.

For local testing, you can:
- Copy `out/openvmm-deps/sysroot.tar.gz` to `<openvmm src>/.packages/openvmm-deps/`
- untar the file to overwrite the libs
- rebuild openvmm

To build only one target (e.g. just a kernel) use `--target`:

```bash
docker build --platform x86_64 --target result-linux-6.1 \
  --output type=local,dest=out/linux-6.1 .
```
