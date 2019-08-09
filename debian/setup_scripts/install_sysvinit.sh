#!/usr/bin/env bash
set -e

apt-get install -y sysvinit-core apt-utils netbase busybox ifupdown isc-dhcp-client

# Use sysvinit to provide /init
ln -s /sbin/init /init

echo "
id:3:initdefault:

si::sysinit:/etc/init.d/rcS

~:S:wait:/sbin/sulogin --force


l0:0:wait:/etc/init.d/rc 0
l1:1:wait:/etc/init.d/rc 1
l2:2:wait:/etc/init.d/rc 2
l3:3:wait:/etc/init.d/rc 3
l4:4:wait:/etc/init.d/rc 4
l5:5:wait:/etc/init.d/rc 5
l6:6:wait:/etc/init.d/rc 6
z6:6:respawn:/sbin/sulogin --force

ca:12345:ctrlaltdel:/sbin/shutdown -t1 -a -r now


pf::powerwait:/etc/init.d/powerfail start
pn::powerfailnow:/etc/init.d/powerfail now
po::powerokwait:/etc/init.d/powerfail stop


T0:2345:respawn:/sbin/getty -L console 115200 vt100
" > /etc/inittab

# Install busybox
busybox --install -s
