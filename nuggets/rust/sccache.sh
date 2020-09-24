#!/usr/bin/env sh

set -e

NEEDS_BUILD="0"
if ! [ -f "/home/remi/.cargo/bin/sccache" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$(sccache --version)
  if [ "${CURRENT_VERSION}" != "sccache ${SCCACHE}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  echo "Build sccache"
  cargo install sccache
fi
