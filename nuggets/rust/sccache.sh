#!/usr/bin/env sh

set -e

NEEDS_BUILD="0"
if ! [ -f "/home/remi/.cargo/bin/sccache" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$(sccache --version)
  if [ "${CURRENT_VERSION}" != "sccache 0.2.14-alpha.0" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  cargo install sccache --git https://github.com/mozilla/sccache.git --rev "${SCCACHE}"
fi
