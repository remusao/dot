#!/usr/bin/env bash

set -e

NEEDS_BUILD="0"
if ! [ -f "${HOME}/.cargo/bin/sccache" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$("${HOME}/.cargo/bin/sccache" --version)
  if [ "${CURRENT_VERSION}" != "sccache ${SCCACHE}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  cargo install sccache --locked
fi
