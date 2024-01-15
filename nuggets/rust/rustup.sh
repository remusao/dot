#!/usr/bin/env sh

set -e

if ! [ -f "/home/remi/.cargo/bin/rustup" ]; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
else
  rustup self update
fi

rustup toolchain install stable --component rust-src rust-analyzer clippy rust-docs rustfmt cargo
