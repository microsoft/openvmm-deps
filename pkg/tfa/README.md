# TF-A Firmware

This package builds Trusted Firmware-A for OpenVMM's Arm CCA QEMU tests.

The `7.1-rc1-kvm-cca` firmware is pinned to TF-A
`v2.15.0` commit `da738d5eae93`, uses the QEMU `virt` platform, enables
FEAT_RME/RMM, and includes the matching TF-RMM `rmm.img` via TF-A's standard
`RMM=` build input.

It is built for Linux direct boot:

```text
ARM_LINUX_KERNEL_AS_BL33=1
PRELOADED_BL33_BASE=0x40080000
ARM_PRELOADED_DTB_BASE=0x40000000
```

`0x40080000` matches QEMU `virt`'s default arm64 `-kernel Image` load address
for RAM base `0x40000000` plus the kernel Image `text_offset` (`0x80000`).
QEMU generates the DTB at `0x40000000`; TF-A passes that address to Linux in
`x0`.

The release artifact is:

```text
openvmm-test-tfa-7.1-rc1-kvm-cca.aarch64.<release>.tar.gz
```

It contains:

```text
flash.bin     # ready-to-use secure flash image for QEMU -bios
bl1.bin       # TF-A BL1
bl2.bin       # TF-A BL2
bl31.bin      # TF-A BL31/RMMD
fip.bin       # firmware image package containing BL2, BL31, and RMM
*.elf, *.map  # debug artifacts when produced by TF-A
boot-info.txt # build-time handoff addresses and firmware configuration
```
