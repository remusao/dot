#!/usr/bin/env bash
set -e

# Source build: upstream ships no release assets. `--locked` only asserts the
# crates.io graph's integrity, not provenance of this unverified git ref.

DATA_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}"

# Icons/themes/manpage land after the binary, so gating on the binary alone
# latches a half-install: this box sat at 0.36.1 with i3status-rs.1 never written.
NEEDS_BUILD="0"
if ! [ -x "${HOME}/.cargo/bin/i3status-rs" ] \
  || ! [ -d "${DATA_DIR}/i3status-rust/icons" ] \
  || ! [ -d "${DATA_DIR}/i3status-rust/themes" ] \
  || ! [ -f "${DATA_DIR}/man/man1/i3status-rs.1" ]; then
  NEEDS_BUILD="1"
else
  # Non-fatal probe: a version-stamped .so (PulseAudio's) can leave the binary
  # unable to run, and update.sh's pipefail would abort instead of rebuilding.
  CURRENT_VERSION=$("${HOME}/.cargo/bin/i3status-rs" --version 2>/dev/null | awk '{print $2}' || true)
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

    # Inlines upstream ./install.sh, which has no `set -e`: a failed icon copy
    # exits 0, and config.toml resolves icons=awesome6 from DATA_DIR at runtime,
    # so the bar breaks. Its `cargo xtask` alias is also a debug build.
    install -d "${DATA_DIR}/i3status-rust"
    cp -r files/. "${DATA_DIR}/i3status-rust/"
    cargo run --release --locked --quiet --package xtask -- generate-manpage
    install -Dm644 man/i3status-rs.1 "${DATA_DIR}/man/man1/i3status-rs.1"
  )
fi
