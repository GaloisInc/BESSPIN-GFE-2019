#!/usr/bin/env bash
set -e

# Prevent installing unnecessary docs and locales
echo "
path-exclude=/usr/share/man/*
path-exclude=/usr/share/locale/*
path-include=/usr/share/locale/locale.alias
path-exclude=/usr/share/doc/*
path-include=/usr/share/doc/*/copyright
path-exclude=/usr/share/dict/*
" >/etc/dpkg/dpkg.cfg.d/exclude

# Reinstall all packages to make it take effect
dpkg --get-selections | \
    awk '{print $1}' |
    xargs apt-get --reinstall install -y
