# TF-RMM Firmware

This package builds TF-RMM firmware for OpenVMM's Arm CCA QEMU tests.

The `7.1-rc1-kvm-cca` firmware is pinned to TF-RMM
`topics/rmm-v2.0-poc_2` commit `3340667a291a`, matching the RMM v2.0-bet1
firmware branch called out by the KVM CCA v14 patchset. It uses
`qemu_virt_defcfg` and ships only for `aarch64`.

The release artifact is:

```text
openvmm-test-rmm-7.1-rc1-kvm-cca.aarch64.<release>.tar.gz
```

It contains:

```text
rmm.img       # primary firmware image for TF-A/BL31
rmm.elf       # ELF copy kept by TF-RMM for CI/debug compatibility
rmm_core.img  # raw RMM core image before EL0 app bundling
rmm_core.elf  # RMM core ELF
rmm_core.map  # linker map
```

TF-RMM's upstream CMake build normally runs `git submodule update` during
configure. In this repository, all TF-RMM submodules are pinned explicitly as
Docker source stages and copied into `ext/` before configure, so the build does
not fetch unpinned source during CMake configure.
