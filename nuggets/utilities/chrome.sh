#!/usr/bin/env bash
set -e

if ! dpkg -s google-chrome-stable &>/dev/null; then
  (
    DEB=$(mktemp --suffix=.deb)
    trap 'rm -f "$DEB"' EXIT
    wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O "$DEB"
    chmod 644 "$DEB"
    sudo apt-get install -y "$DEB"
  )
fi
