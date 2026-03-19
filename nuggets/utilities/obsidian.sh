#!/usr/bin/env bash
set -e

NEEDS_BUILD="0"
if ! dpkg -s obsidian &>/dev/null; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$(dpkg-query -W -f='${Version}' obsidian)
  if [ "${CURRENT_VERSION}" != "${OBSIDIAN_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    DEB=$(mktemp --suffix=.deb)
    trap 'rm -f "$DEB"' EXIT
    wget -q "https://github.com/obsidianmd/obsidian-releases/releases/download/v${OBSIDIAN_VERSION}/obsidian_${OBSIDIAN_VERSION}_amd64.deb" -O "$DEB"
    chmod 644 "$DEB"
    sudo apt-get install -y "$DEB"
  )
fi
