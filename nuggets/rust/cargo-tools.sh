#!/usr/bin/env bash

set -e

CARGO_BIN="${HOME}/.cargo/bin"

# Helper: install a cargo crate if missing or version differs.
# Usage: cargo_ensure <crate> <binary> <version> [extra_args...]
#   Version is matched anywhere in `<binary> --version` output.
# cargo checks each .crate's sha256 from the index; no signatures = no provenance.
cargo_ensure() {
  local crate="$1" binary="$2" version="$3"
  shift 3

  # An empty pin matches anything below, so an installed tool never rebuilds.
  if [ -z "$version" ]; then
    printf 'cargo_ensure: empty version pin for %s\n' "$crate" >&2
    return 1
  fi

  local needs_build="0"
  if ! [ -x "${CARGO_BIN}/${binary}" ]; then
    needs_build="1"
  else
    # Match the pinned version anywhere in `--version` output — some tools (eza)
    # print the number on line 2, so don't restrict to the first line. Anchored
    # on non-version chars so a 0.6.1 pin can't match an installed 0.6.14.
    if ! "${CARGO_BIN}/${binary}" --version 2>/dev/null \
      | grep -qE "(^|[^0-9.])${version//./\\.}([^0-9.]|\$)"; then
      needs_build="1"
    fi
  fi

  if [ "$needs_build" = "1" ]; then
    cargo install "$crate" --version "$version" --locked "$@"
  fi
}

cargo_ensure cargo-audit   cargo-audit   "${CARGO_AUDIT_VERSION}"
cargo_ensure cargo-deny    cargo-deny    "${CARGO_DENY_VERSION}"
cargo_ensure cargo-fuzz    cargo-fuzz    "${CARGO_FUZZ_VERSION}"
cargo_ensure flamegraph    flamegraph    "${FLAMEGRAPH_VERSION}"
# loc 0.5.0 (2018, final) ships no Cargo.lock, so --locked only warns and its
# deps float — accepted, the only fix is a --git/--rev pin bump.sh can't track.
cargo_ensure loc           loc           "${LOC_VERSION}"
cargo_ensure oxipng        oxipng        "${OXIPNG_VERSION}"
cargo_ensure tokei         tokei         "${TOKEI_VERSION}"
cargo_ensure tree-sitter-cli tree-sitter "${TREE_SITTER_CLI_VERSION}"
cargo_ensure eza           eza           "${EZA_VERSION}"
cargo_ensure du-dust       dust          "${DU_DUST_VERSION}"
cargo_ensure difftastic    difft         "${DIFFTASTIC_VERSION}"
