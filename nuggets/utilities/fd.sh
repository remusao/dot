#!/usr/bin/env bash

set -e

. "$(dirname "${BASH_SOURCE[0]}")/../lib/verify.sh"

# All three guarded: a step added later never runs once the version matches.
NEEDS_BUILD="0"
if ! [ -f "${HOME}/.local/bin/fd" ] ||
  ! [ -f "${HOME}/.zsh_functions/_fd" ] ||
  ! [ -f "${HOME}/.local/share/man/man1/fd.1" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$("${HOME}/.local/bin/fd" --version 2>/dev/null | awk '{print $2}') ||
    CURRENT_VERSION=""
  if [ "${CURRENT_VERSION}" != "${FD_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT

    # gnu, not musl: neither prebuilt ships jemalloc and musl's mallocng
    # serializes fd's threaded walker; fd is FZF_DEFAULT_COMMAND, so that cost
    # is every CTRL-T. No upstream checksums for any asset -- TLS only.
    pkg="fd-v${FD_VERSION}-x86_64-unknown-linux-gnu"
    curl_fetch \
      "https://github.com/sharkdp/fd/releases/download/v${FD_VERSION}/${pkg}.tar.gz" \
      "${tmp}/fd.tar.gz"
    tar -xzf "${tmp}/fd.tar.gz" -C "$tmp"
    chmod 755 "${tmp}/${pkg}/fd"
    mv "${tmp}/${pkg}/fd" "${HOME}/.local/bin/fd"

    # _fd only works because zshrc puts ~/.zsh_functions in fpath.
    install -Dm644 "${tmp}/${pkg}/autocomplete/_fd" "${HOME}/.zsh_functions/_fd"
    install -Dm644 "${tmp}/${pkg}/fd.1" "${HOME}/.local/share/man/man1/fd.1"
  )
fi
