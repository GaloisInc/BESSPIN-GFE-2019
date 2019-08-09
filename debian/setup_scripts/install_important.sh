#!/usr/bin/env bash
set -e

# Install all packages marked "Priority: important".  This mimics the default
# behavior of `mmdebstrap`.  The "important" set contains systemd and some
# other basic packages.
apt-cache dumpavail | \
    awk '/^Package: / { pkg = $2; } /^Priority: important/ { print pkg; }' |
    xargs apt-get install -y --no-install-recommends

#netcat is needed to communicated with the OS after booting. Used for both qemu and hardware.
apt-get install -y netcat
