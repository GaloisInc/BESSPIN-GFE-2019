#!/bin/bash

cd /

# Exclude /host-rootfs and /nix completely.  Include /proc, /sys, and /tmp, but
# not any of their children (they will appear as empty directories).
find . \
    -path ./debian.cpio.gz -o \
    -path ./host-rootfs -prune -o \
    -path ./nix -prune -o \
    -path ./proc -prune -print0 -o \
    -path ./sys -prune -print0 -o \
    -path ./tmp -prune -print0 -o \
    -print0 | \
    cpio --null --create --format=newc | \
    gzip --best >/debian.cpio.gz
