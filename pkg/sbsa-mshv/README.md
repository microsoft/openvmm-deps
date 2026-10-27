# SBSA MSHV Firmware

This package builds the paired flash images used by the standalone ARM64
MSHV Incubator on QEMU `sbsa-ref`. It does not replace the Linux-direct QEMU
`virt` CCA firmware in `pkg/tfa` and `pkg/rmm`.

The sources are pinned in the Dockerfile:

| Component | Revision |
| --- | --- |
| TF-A v2.14.0 | `1d5aa939bc8d3d892e2ed9945fa50e36a1a924cc` |
| EDK2 | `80fd66aef9ba7275380935622d5558cb2c6488e5` |
| edk2-platforms | `349207b2dce9467c2c8dc90efd70c55c1fc4d3d1` |

Git source stages include submodules at the revisions recorded by their
superprojects. Compilation runs without network access, using Ubuntu 24.04's
AArch64 GNU cross compiler and native EDK2 BaseTools.

TF-A uses `PLAT=qemu_sbsa DEBUG=1`, with RME disabled and no RMM. Its BL1 and
FIP are staged as the firmware inputs expected by the SBSA EDK2 platform;
no prebuilt `edk2-non-osi` binaries are used. UEFI uses the `RELEASE` build
target and `GCC` toolchain.

Two patches preserve the validated Incubator configuration:

- Include the standard virtio PCI transport and block drivers so UEFI can
  read the Incubator boot disk.
- Honor `PcdUninstallMemAttrProtocol` in the Arm boot manager, and build with
  it enabled. This temporarily works around HvLoader binding imports after
  making its IAT read-only. **This weakens firmware image protection and is
  for development/testing only.** Remove it when the loader is fixed.

The artifact does not contain HvLoader, `lxhvloader.dll`, Hyper-V, or other
Windows payloads. Fetch the public `HvLoader.efi` application from the
separate [HvLoader artifact](../hvloader/README.md), and supply the DLL and
hypervisor runtime separately.

The release archive is:

```text
openvmm-test-sbsa-mshv.aarch64.<release>.tar.gz
```

It contains:

```text
SBSA_FLASH0.fd  # TF-A secure firmware, read-only
SBSA_FLASH1.fd  # UEFI code and writable variable store
manifest.txt   # source/patch revisions, configuration, toolchain, image hashes
```

Both images are padded to the 256 MiB bank size expected by `sbsa-ref`.
Use them together from the same build. Always make a disposable writable
copy of flash1 for each run; it is not a variables-only image.

To build only this artifact:

```bash
docker buildx build --platform aarch64 --target result-sbsa-mshv \
    --output type=local,dest=out/sbsa-mshv .
```

The normal `packages-aarch64` CI target also builds and archives it.
