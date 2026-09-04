# TF-RMM Firmware

This package builds TF-RMM firmware for OpenVMM's Arm CCA QEMU tests.

The `cca` firmware is pinned to TF-RMM v2 integration commit
`f00eac344b6f`, which implements the RMI 2.0 interface required by the KVM CCA
v15 patchset. It uses `qemu_virt_defcfg` and ships only for `aarch64`.

The release artifact is:

```text
openvmm-test-rmm-cca.aarch64.<release>.tar.gz
```

It contains:

```text
rmm.img       # primary firmware image for TF-A/BL31
rmm.elf       # ELF copy kept by TF-RMM for CI/debug compatibility
rmm_core.img  # raw RMM core image before EL0 app bundling
rmm_core.elf  # RMM core ELF
rmm_core.map  # linker map
manifest.txt  # source, submodule, patch, toolchain, config, and output digests
```

TF-RMM's upstream CMake build normally runs `git submodule update` during
configure. In this repository, all TF-RMM submodules are pinned explicitly as
Docker source stages and copied into `ext/` before configure, so the build does
not fetch unpinned source during CMake configure.
