#!/usr/bin/env bash

set -e

NEEDS_BUILD="0"
if ! command -v libinput-gestures &>/dev/null; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$(libinput-gestures --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+' || echo "")
  if [ "${CURRENT_VERSION}" != "${LIBINPUT_GESTURES_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    git clone --depth=1 --branch "${LIBINPUT_GESTURES_VERSION}" \
      https://github.com/bulletmark/libinput-gestures.git "$tmp"
    sudo make -C "$tmp" install
  )
fi
