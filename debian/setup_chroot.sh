#!/usr/bin/env bash
set -e

# This script runs inside the chroot after basic setup is complete.  You can
# customize it to change the set of packages installed or to set up custom
# configuration files.

debian_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
setup_scripts_dir="${debian_dir}/setup_scripts"

"${setup_scripts_dir}/exclude_docs.sh"

# Install an init system.
"${setup_scripts_dir}/install_systemd.sh"
#"${setup_scripts_dir}/install_sysvinit.sh"


# Common setup

# Set root password
yes riscv | passwd

# Modify network configuration
echo "
# Use DHCP to automatically configure eth0
auto eth0
allow-hotplug eth0
iface eth0 inet dhcp
" >> /etc/network/interfaces

# Remove debconf internationalization for debconf
dpkg --remove debconf-i18n

# apt-get then cleanup
apt-get update
apt-get autoremove -y
apt-get clean
rm -f /var/lib/apt/lists/*debian*
