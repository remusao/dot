#!/usr/bin/env bash

set -e

CARGO_BIN="${HOME}/.cargo/bin"

# Helper: install a cargo crate if missing or version differs.
# Usage: cargo_ensure <crate> <binary> <version> [extra_args...]
#   Version is matched against the first line of `<binary> --version`.
cargo_ensure() {
  local crate="$1" binary="$2" version="$3"
  shift 3

  local needs_build="0"
  if ! [ -f "${CARGO_BIN}/${binary}" ]; then
    needs_build="1"
  else
    local current
    current=$("${CARGO_BIN}/${binary}" --version 2>/dev/null | head -n 1)
    if ! echo "$current" | grep -qF "$version"; then
      needs_build="1"
    fi
  fi

  if [ "$needs_build" = "1" ]; then
    cargo install "$crate" --locked "$@"
  fi
}

cargo_ensure cargo-audit   cargo-audit   "${CARGO_AUDIT}"
cargo_ensure cargo-fuzz    cargo-fuzz    "${CARGO_FUZZ}"
cargo_ensure flamegraph    flamegraph    "${FLAMEGRAPH}"
cargo_ensure loc           loc           "${LOC}"
cargo_ensure oxipng        oxipng        "${OXIPNG}"
cargo_ensure tokei         tokei         "${TOKEI}"
cargo_ensure tree-sitter-cli tree-sitter "${TREE_SITTER_CLI}"
cargo_ensure eza           eza           "${EZA}"
cargo_ensure du-dust       dust          "${DU_DUST}"
cargo_ensure difftastic    difft         "${DIFFTASTIC}"
