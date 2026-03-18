#!/usr/bin/env bash

set -e

if ! [ -f "${HOME}/.cargo/bin/rustup" ]; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

# Ensure cargo bin is in PATH for this session
export PATH="${HOME}/.cargo/bin:${PATH}"

rustup self update || true
rustup toolchain install stable --component rust-src
