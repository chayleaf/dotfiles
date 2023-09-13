# Radxa Rock 5A

Use https://github.com/edk2-porting/edk2-rk3588 (A UEFI implementation)
instead of U-Boot

Mainline kernel works, as long as it's sufficiently new.

I use the SATA hat, which needed an overlay to enable PCIe. Also, the
ethernet adapter isn't connected via PCIe, it needs the `dwmac-rk`
kernel module (normally it should be loaded automatically, but I need it
in initrd).
