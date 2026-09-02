#!/usr/bin/env bash

set -e

. "$(dirname "${BASH_SOURCE[0]}")/../lib/verify.sh"

# Man page and completion are in the guard too: once the version matches
# nothing re-fetches them, so a binary-only install would stay that way.
NEEDS_BUILD="0"
if ! [ -x "${HOME}/.local/bin/hyperfine" ] ||
  ! [ -f "${HOME}/.local/share/man/man1/hyperfine.1" ] ||
  ! [ -f "${HOME}/.zsh_functions/_hyperfine" ]; then
  NEEDS_BUILD="1"
else
  # set -e: an unrunnable binary must reinstall, not abort the run.
  CURRENT_VERSION=$("${HOME}/.local/bin/hyperfine" --version 2>/dev/null | awk '{print $2}') || CURRENT_VERSION=""
  if [ "${CURRENT_VERSION}" != "${HYPERFINE_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT

    # Upstream publishes no checksums or signatures, so TLS is the ceiling.
    pkg="hyperfine-v${HYPERFINE_VERSION}-x86_64-unknown-linux-musl"
    curl_fetch \
      "https://github.com/sharkdp/hyperfine/releases/download/v${HYPERFINE_VERSION}/${pkg}.tar.gz" \
      "${tmp}/hyperfine.tar.gz"
    tar -xzf "${tmp}/hyperfine.tar.gz" -C "$tmp"
    chmod 755 "${tmp}/${pkg}/hyperfine"
    mv "${tmp}/${pkg}/hyperfine" "${HOME}/.local/bin/hyperfine"

    # The completion is only found via the fpath entry in zshrc.
    install -Dm644 "${tmp}/${pkg}/autocomplete/_hyperfine" "${HOME}/.zsh_functions/_hyperfine"
    install -Dm644 "${tmp}/${pkg}/hyperfine.1" "${HOME}/.local/share/man/man1/hyperfine.1"
  )
fi
