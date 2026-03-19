#!/usr/bin/env bash
set -e

NEEDS_BUILD="0"
if ! [ -f "${HOME}/.cargo/bin/i3status-rs" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$("${HOME}/.cargo/bin/i3status-rs" --version 2>&1 | awk '{print $2}' | sed 's/^v//')
  if [ "${CURRENT_VERSION}" != "${I3STATUS_RUST_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    git clone --depth=1 --branch "v${I3STATUS_RUST_VERSION}" \
        https://github.com/greshake/i3status-rust.git "$tmp"
    cd "$tmp"
    cargo install --path . --locked
    ./install.sh
  )
fi
