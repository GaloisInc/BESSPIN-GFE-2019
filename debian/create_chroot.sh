#!/usr/bin/env bash
set -e


# Debian riscv64 chroot build script
#
# Usage:
#   ./test_chroot.sh [OPERATION...]
#
# `OPERATION` defaults to `main`, which runs the entire chroot build process.
#
# Other operations:
#
# - `stage0` .. `stage2`: Runs an individual stage of the build process.  The
#   default command, `main`, simply runs each stage in order.
#
# - `as_fake_root CMD...`: Runs `CMD`, emulating root permissions.  For
#   example, running `./create_chroot.sh as_fake_root id -u` should print 0.
#   This also permits running privileged filesystem operations, such as `chown`
#   or `mknod`, though the effects of these operations will only be visible
#   inside the emulated environment.
#
# - `in_chroot CMD...`: Runs `CMD` in the full emulated riscv64 chroot
#   environment.  `CMD` will appear to run as the root user, on riscv64
#   architecture, with `riscv64-chroot` as its root directory.  

# Dependencies: debootstrap, proot, fakeroot, and qemu-user


# Get the path to debian directory script is being run from 
debian_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
chroot_dir="$debian_dir/riscv64-chroot"
gfe_dir="$(dirname "$debian_dir")"
# Path to the script itself.  Used to run parts under proot/fakeroot
self="${debian_dir}/$(basename "${BASH_SOURCE[0]}")"
build_dir="$debian_dir/build"

# Pointing to a particular snapshot of debian as the master repo can be unstable!
#debian_url="https://snapshot.debian.org/archive/debian-ports/20190424T014031Z/"
debian_url="http://deb.debian.org/debian-ports/"

: ${DEBIAN_PORTS_ARCHIVE_KEYRING:=/usr/share/keyrings/debian-ports-archive-keyring.gpg}


edo() {
    echo $'\x1b[35;1m >>>' "$@" $'\x1b[0m'
    "$@"
}

# Run a command
as_fake_root() {
    local fakeroot_state="$build_dir/fakeroot.state"
    fakeroot -s "$fakeroot_state" -i "$fakeroot_state" -- "$@"
}

in_chroot() {
    local cmd=()

    # Run a command inside the chroot, using a combination of proot and
    # fakeroot.

    # Note: while it seems like it would be simpler to flip this around and run
    # proot inside fakeroot, I couldn't get it to work.  Probably an issue with
    # library search paths getting mixed up, or maybe with cross-architecture
    # differences in the libfakeroot<->faked wire format.  So for now, we stick
    # with fakeroot-in-proot.

    # proot handles filesystem translation (chroot emulation) and architecture
    # translation (via qemu).
    cmd+=(
        proot

        # Filesystem translation
        --rootfs="$chroot_dir"
        --bind=/proc --bind=/sys
        --cwd=/

        # Architecture translation
        --qemu=qemu-riscv64

        # --bind=/nix is necessary when using nix-compiled qemu.  The --qemu
        # binary runs under proot's filesystem emulation, effectively inside
        # the chroot.  proot does some amount of translation (prefixing library
        # search paths with /host-rootfs) to make dynamic qemu binaries work,
        # but it's not sufficient to handle nix's nonstandard locations and
        # extensive use of RPATHs.  (The visible symptom of this is
        # qemu-riscv64 complaining that it's missing libpcre.so.1.)  Binding
        # /nix makes the paths line up properly.  Another, probably better fix
        # would be to use a statically linked qemu.
        --bind=/nix
    )

    # Reset PATH and LD_LIBRARY_PATH.  proot will actually translate paths in
    # both variables, causing scripts to run the host versions of commands.
    # This step ensures they only see the target versions instead.
    #
    # Also set TMPDIR to /tmp, instead of inheriting the setting from the host
    # environment.  Under some configurations (including the one on the CI
    # runner), TMPDIR is set to /run/user/$UID/, which doesn't exist inside the
    # chroot.
    cmd+=(
        /usr/bin/env
        -u LD_LIBRARY_PATH
        PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
        TMPDIR=/tmp
    )

    # Path to riscv64 fakeroot files, as seen from inside `proot`
    local fakeroot_dir="/host-rootfs/$build_dir/fakeroot/usr"
    local fakeroot_state="/host-rootfs/$build_dir/fakeroot.state"

    # fakeroot handles uid translation, file ownership, and special file
    # operations (`mknod`).  proot can do some uid translation itself, but it
    # doesn't work very well.
    #
    # Since we're already running under the proot/qemu architecture
    # translation layer, we need a riscv64 version of fakeroot.  `stage1`
    # unpacks this into the build directory (outside the chroot), and that's
    # the copy we use (via `/host-rootfs/`).  We can't just install fakeroot
    # into the chroot normally because dpkg isn't set up yet the first time we
    # enter the chroot.
    cmd+=(
        "$fakeroot_dir/bin/fakeroot-sysv"
        -l "$fakeroot_dir/lib/riscv64-linux-gnu/libfakeroot/libfakeroot-sysv.so"
        --faked "$fakeroot_dir/bin/faked-sysv"
        -s "$fakeroot_state" -i "$fakeroot_state"
        --
    )

    # The actual command to run inside the chroot.
    cmd+=( "$@" )

    "${cmd[@]}"
}

# Run a subcommand of this script inside the chroot.
as_fake_root_self() {
    as_fake_root bash "$self" "$@"
}

# Run a subcommand of this script inside the chroot.
in_chroot_self() {
    in_chroot bash "/host-rootfs/$self" "$@"
}

# chroot setup, stage 0.  Runs as the normal user on the host machine.
stage0() {
    # Create chroot
    if [ -d "$chroot_dir" ]; then
        echo "Please remove $chroot_dir then run again"
        exit 1;
    fi
    if [ -d "$build_dir" ]; then
        echo "Please remove $build_dir then run again"
        exit 1;
    fi

    edo mkdir "$chroot_dir" "$build_dir"
    edo touch "$build_dir/fakeroot.state"
}

# chroot setup, stage 1.  This runs as (fake) root, but on the host machine.
stage1_inner() {
    # Download and unpack initial packages.  This uses --foreign, meaning it
    # doesn't actually run package install scripts yet.
    edo debootstrap \
        --include=fakeroot,debian-ports-archive-keyring \
        --variant=minbase --foreign --arch=riscv64 \
        --no-merged-usr \
        --keyring $DEBIAN_PORTS_ARCHIVE_KEYRING \
        --verbose \
        sid $chroot_dir $debian_url

    # Manually unpack fakeroot + libfakeroot into the build dir.  We don't
    # actually need fakeroot installed inside the chroot - passing it to
    # `debootstrap --include` is just a convenient way to get the packages
    # downloaded.
    edo dpkg -x $chroot_dir/var/cache/apt/archives/fakeroot*.deb $build_dir/fakeroot
    edo dpkg -x $chroot_dir/var/cache/apt/archives/libfakeroot*.deb $build_dir/fakeroot
}

stage1() {
    as_fake_root_self stage1_inner
}

# chroot setup, stage 2.  This runs inside the chroot, under proot + fakeroot
stage2_inner() {
    edo /debootstrap/debootstrap --second-stage
    edo apt-get remove -y --purge fakeroot libfakeroot
}

stage2() {
    in_chroot_self stage2_inner
}

stage3() {
    in_chroot "/host-rootfs/$debian_dir/setup_chroot.sh"
}

main() {
    edo stage0
    edo stage1
    edo stage2
    edo stage3
}

create_cpio() {
    in_chroot "/host-rootfs/$debian_dir/setup_scripts/create_cpio.sh"
}


if [ "$#" -eq 0 ]; then
    main
# If $1 is a function, run it.  Otherwise, complain.
elif declare -f "$1" >/dev/null; then
    "$@"
else
    echo "unknown subcommand $1"
fi
