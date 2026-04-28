#!/usr/bin/env bash

set -e

NEEDS_BUILD="0"
if ! command -v snixembed &>/dev/null; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$(snixembed --version 2>/dev/null | awk '{print $2}')
  if [ "${CURRENT_VERSION}" != "${SNIXEMBED_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  sudo apt-get install --yes valac libgtk-3-dev libdbusmenu-gtk3-dev

  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    git clone --depth=1 --branch "${SNIXEMBED_VERSION}" \
      https://git.sr.ht/~steef/snixembed "${tmp}"
    cd "${tmp}"
    make PREFIX=/usr/local
    sudo make PREFIX=/usr/local install
  )
fi
