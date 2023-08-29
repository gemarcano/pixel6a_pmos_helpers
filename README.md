# Pixel 6A postmarketOS Helpers

This is a collection of utilities for working with postmarketOS on the Pixel
6A.

## Dependencies

The python scripts from the following repositories should be in `PATH`:
 - https://android.googlesource.com/platform/system/tools/mkbootimg
 - https://android.googlesource.com/platform/external/avb

- fastboot
- openssl

## Utilities

### `flash_and_boot.sh`

Used to flash boot image, and then immediately boot from it.

### `prepare_boot_img.sh`

Takes in the `boot.img` and `vendor_boot.img` from Android, and a generated
postmarketOS initramfs, and combines them to the target image (and signs it so
the bootloader doesn't get angry).

Example:
```
./prepare_boot_img.sh ../google-kernel/out/mixed/dist/boot.img \
    ../google-kernel/out/mixed/dist/vendor_boot.img \
    ../postmarket_initramfs.cpio.lz new_boot.img
```

### `share_internet.sh`

Adds firewall rules to the host to enable NAT. May additionally require:
```
sysctl net.ipv4.ip_forward=1
```

## License

Under Apache 2.0. See LICENSE file for details.
