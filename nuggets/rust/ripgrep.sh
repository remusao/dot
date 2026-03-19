#!/usr/bin/env bash

set -e

NEEDS_BUILD="0"
if ! [ -f "${HOME}/.cargo/bin/rg" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$("${HOME}/.cargo/bin/rg" --version | head -n 1)
  if [ "${CURRENT_VERSION}" != "ripgrep ${RIPGREP_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  RUSTFLAGS="-C target-cpu=native" cargo install ripgrep --locked --features pcre2
fi
