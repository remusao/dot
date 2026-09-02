#!/usr/bin/env bash

set -e

. "$(dirname "${BASH_SOURCE[0]}")/../lib/verify.sh"

# Bootstrap from archive/ rather than piping sh.rustup.rs into a shell: that
# endpoint serves a floating rustup-init and publishes no checksum, while the
# per-version tree publishes a .sha256 next to the binary. Same origin as the
# artifact, so this is integrity, not provenance. RUSTUP_PIN only bounds this
# first install -- `rustup self update` below moves it afterwards.
if ! [ -f "${HOME}/.cargo/bin/rustup" ]; then
  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    url="https://static.rust-lang.org/rustup/archive/${RUSTUP_PIN}/x86_64-unknown-linux-gnu/rustup-init"
    fetch_verified "$url" "${tmp}/rustup-init" "${url}.sha256" rustup-init
    chmod 755 "${tmp}/rustup-init"
    # --no-modify-path: rustup-init would append `. ~/.cargo/env` to ~/.profile,
    # ~/.bashrc and ~/.zshenv, none of which this repo manages, and zshrc
    # already puts ~/.cargo/bin on PATH.
    "${tmp}/rustup-init" -y --no-modify-path
  )
fi

# Ensure cargo bin is in PATH for this session
export PATH="${HOME}/.cargo/bin:${PATH}"

rustup self update || true
rustup toolchain install stable --component rust-src --component rust-analyzer
