#!/usr/bin/env sh

set -e

NEEDS_BUILD="0"
if ! [ -f "/home/remi/.local/bin/rust-analyzer" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$(rust-analyzer --version)
  if [ "${CURRENT_VERSION}" != "rust-analyzer ${RUST_ANALYZER}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  cargo install rust-analyzer --git https://github.com/rust-analyzer/rust-analyzer.git --rev "${RUST_ANALYZER}"
fi
