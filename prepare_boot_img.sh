#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Gabriel Marcano, 2023

set -e

if [ "$#" -ne 4 ]
then
	echo "$0 [boot.img] [vendor_boot.img] [pmos_initramfs.cpio.{lz4,gz}] [new_boot.img]"
	exit 1
fi

unpack_initramfs() {
	TYPE=$(file -L "$1")
	echo "$TYPE"
	if echo "$TYPE" | grep -qi gzip
	then
		gzip -dc "$1" | cpio -i -D "$2"
	elif echo "$TYPE" | grep -qi lz4
	then
		lz4 -dc "$1" | cpio -i -D "$2"
	else
		exit 2
	fi
}

cleanup() {
	rm -rf "$DIR"
}

# The basic gist of what we need to do:
#  1. Unpack original GKI boot.img, which gives us a kernel and a base initramfs which we will overwrite
#  2. Unpack the vendor_boot initramfs, from which we'll take the boot modules
#  3. Unpack the pmOS initramfs, to which we'll install the boot modules
#  4. Package up a new boot.img, and sign it

BOOT_IMG="$1"
VENDOR_BOOT="$2"
PMOS_INITRAMFS="$3"
BOOT_IMG_NEW="$4"

# get boot.img
DIR=$(mktemp -d)
trap cleanup INT EXIT

unpack_bootimg.py --boot_img "$BOOT_IMG" --out "$DIR" --format mkbootimg > "$DIR"/boot_flags
unpack_bootimg.py --boot_img "$VENDOR_BOOT" --out "$DIR" --format mkbootimg > "$DIR"/vendor_flags

mkdir "$DIR"/initramfs_new "$DIR"/initramfs_old
unpack_initramfs "$DIR"/vendor-ramdisk-by-name/ramdisk_dlkm "$DIR"/initramfs_old
unpack_initramfs "$PMOS_INITRAMFS" "$DIR"/initramfs_new

OLD_VERSION=$(ls "$DIR"/initramfs_old/lib/modules)
VERSION=$(lz4 -dc "$DIR"/kernel | strings | awk '/Linux version [0-9]/{ print $3 }')
echo $OLD_VERSION $VERSION
rm -r "$DIR"/initramfs_new/lib/modules/*
cp -r "$DIR"/initramfs_old/lib/modules/"$OLD_VERSION" "$DIR"/initramfs_new/lib/modules/"$VERSION"
cd "$DIR/initramfs_new"
find . -print0 | cpio --null -o --format=newc | lz4 -l --best > "$DIR"/ramdisk
cd -
sh -c "mkbootimg.py $(cat $DIR/boot_flags) -o \"$BOOT_IMG_NEW\""

if [ ! -f foobar.pem ]
then
	openssl genrsa -out foobar.pem 4096
	openssl rsa -in foobar.pem -pubout -out foobar.pub
fi

# Bootloader freaks out if the signature is not found, so just give a self-signed one
avbtool.py add_hash_footer --partition_size 67108864 --image "$BOOT_IMG_NEW" --key foobar.pem --prop com.android.build.boot.fingerprint:'google/bluejay/bluejay:12/SD2A.220601.004.B2/8852801:user/release-keys' --prop com.android.build.boot.os_version:'13' --prop com.android.build.boot.security_patch:'2022-06-01' --algorithm 'SHA256_RSA4096' --rollback_index 1654041600 --partition_name boot
