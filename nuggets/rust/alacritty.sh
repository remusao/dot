#!/usr/bin/env bash

set -e

NEEDS_BUILD="0"
if ! [ -f "${HOME}/.cargo/bin/alacritty" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$("${HOME}/.cargo/bin/alacritty" --version | awk '{print $2}')
  if [ "${CURRENT_VERSION}" != "${ALACRITTY_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  RUSTFLAGS="-C target-cpu=native" cargo install alacritty --version "${ALACRITTY_VERSION}" --locked
fi
