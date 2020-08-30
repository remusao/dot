#!/usr/bin/env sh

set -e

NEEDS_BUILD="0"
if ! [ -f "/home/remi/.cargo/bin/rg" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$(rg --version | head -n 1)
  if [ "${CURRENT_VERSION}" != "ripgrep ${RIPGREP}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  cargo install ripgrep
fi
