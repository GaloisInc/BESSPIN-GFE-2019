#!/usr/bin/env bash
set -e
setup_scripts_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

"${setup_scripts_dir}/install_important.sh"

# Use systemd to provide /init
ln -s /lib/systemd/systemd /init

# Fixup serial service for slower processors
echo "DefaultTimeoutStartSec=300s" >> /etc/systemd/system.conf

# Disable many services that are not required to boot to a shell
# NOTE: Some of these may be required for your intended application or functionality
systemctl disable cron.service
systemctl disable dbus-org.freedesktop.timesync1.service
systemctl disable e2scrub_reap.service
systemctl disable networking.service
systemctl disable systemd-timesyncd.service
systemctl disable remote-fs.target
systemctl disable apt-daily-upgrade.timer
systemctl disable apt-daily.timer
systemctl disable e2scrub_all.timer
systemctl disable logrotate.timer
systemctl mask network-online.target
systemctl mask sys-fs-fuse-connections.mount
systemctl mask apt-daily-upgrade.service
systemctl mask apt-daily.service
systemctl mask container-getty@.service
systemctl mask dbus-org.freedesktop.hostname1.service
systemctl mask dbus-org.freedesktop.locale1.service
systemctl mask dbus-org.freedesktop.login1.service
systemctl mask dbus-org.freedesktop.timedate1.service
systemctl mask e2scrub@.service
systemctl mask e2scrub_all.service
systemctl mask e2scrub_fail@.service
systemctl mask fstrim.service
systemctl mask getty-static.service
systemctl mask kmod.service
systemctl mask logrotate.service
systemctl mask module-init-tools.service
systemctl mask systemd-bless-boot.service
systemctl mask systemd-fsck-root.service
systemctl mask systemd-fsck@.service
systemctl mask systemd-fsckd.service
systemctl mask systemd-journal-flush.service
systemctl mask systemd-modules-load.service
systemctl mask systemd-update-utmp-runlevel.service
systemctl mask systemd-update-utmp.service
systemctl mask systemd-fsckd.socket
systemctl mask bluetooth.target
systemctl mask time-sync.target
systemctl mask systemd-tmpfiles-clean.timer
systemctl mask sys-subsystem-net-devices-eth0.device
systemctl set-default multi-user.target
ln -sf /dev/null /etc/systemd/system/serial-getty@hvc0.service

# Initialize random-seed
dd if=/dev/urandom of=/var/lib/systemd/random-seed count=1 bs=512 
chmod 600 /var/lib/systemd/random-seed
