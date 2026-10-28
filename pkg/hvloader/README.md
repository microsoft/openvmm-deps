# HvLoader EFI Application

This package builds the public
[microsoft/HvLoader](https://github.com/microsoft/HvLoader) EFI application
for the standalone ARM64 MSHV Incubator. The upstream loader source is
unmodified.

The Dockerfile pins HvLoader to
`fbf04f7cf2cb40c0c5e71ce61c438ff20ec4610d` and reuses the SBSA firmware's
EDK2 revision, `80fd66aef9ba7275380935622d5558cb2c6488e5`, including its pinned
submodules. The loader uses a fresh, unpatched EDK2 tree and the minimal
`HvLoaderBuild.dsc` platform in this directory. Compilation runs without
network access using Ubuntu 24.04's AArch64 GNU cross compiler and native
EDK2 BaseTools.

The ARM64 release archive is:

```text
openvmm-test-hvloader.aarch64.<release>.tar.gz
```

It contains:

```text
HvLoader.efi      # unsigned AARCH64 UEFI application
manifest.txt      # source revisions, platform hash, toolchain, and image hash
LICENSE.HvLoader  # upstream HvLoader license
LICENSE.edk2      # upstream EDK2 license
```

Place `HvLoader.efi` in the boot-artifact directory's `boot/` subdirectory.
It loads the separately supplied `lxhvloader.dll`; neither that DLL nor the
Hyper-V runtime is included or required to build this package.

The application is unsigned: Secure Boot must be disabled unless the user
separately signs and trusts it. Building the public application does not
fix the import-binding issue in the external loader. The current SBSA MSHV
bring-up still requires the development firmware workaround described in
[../sbsa-mshv/README.md](../sbsa-mshv/README.md).

To build only the loader artifact:

```bash
docker buildx build --platform aarch64 --target result-hvloader \
    --output type=local,dest=out/hvloader .
```

The normal `packages-aarch64` CI target also builds and archives it.
