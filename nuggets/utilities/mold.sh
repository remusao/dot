#!/usr/bin/env bash

set -e

. "$(dirname "${BASH_SOURCE[0]}")/../lib/verify.sh"

# The `ld` alias is in the guard because cargo/cc-mold selects mold with
# `-B<dir>`, which needs a program of exactly that name in that dir; a
# binary-only install would leave cc-mold silently falling back to rust-lld.
# The man page is there for the usual reason: once the version matches, nothing
# re-fetches it.
NEEDS_BUILD="0"
if ! [ -x "${HOME}/.local/bin/mold" ] ||
  ! [ -x "${HOME}/.local/libexec/mold/ld" ] ||
  ! [ -f "${HOME}/.local/share/man/man1/mold.1" ]; then
  NEEDS_BUILD="1"
else
  # set -e: an unrunnable binary must reinstall, not abort the run.
  CURRENT_VERSION=$("${HOME}/.local/bin/mold" --version 2>/dev/null | awk '{print $2}') || CURRENT_VERSION=""
  if [ "${CURRENT_VERSION}" != "${MOLD_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT

    # Upstream publishes no checksums or signatures, and its tags are
    # lightweight, so TLS is the ceiling.
    pkg="mold-${MOLD_VERSION}-x86_64-linux"
    curl_fetch \
      "https://github.com/rui314/mold/releases/download/v${MOLD_VERSION}/${pkg}.tar.gz" \
      "${tmp}/mold.tar.gz"
    tar -xzf "${tmp}/mold.tar.gz" -C "$tmp"

    # Only the binary and the `ld` alias. lib/mold/mold-wrapper.so is skipped:
    # it exists solely for `mold -run`, which nothing here uses.
    chmod 755 "${tmp}/${pkg}/bin/mold"
    mv "${tmp}/${pkg}/bin/mold" "${HOME}/.local/bin/mold"
    mkdir -p "${HOME}/.local/libexec/mold"
    ln -sf ../../bin/mold "${HOME}/.local/libexec/mold/ld"

    install -Dm644 "${tmp}/${pkg}/share/man/man1/mold.1" \
      "${HOME}/.local/share/man/man1/mold.1"
  )
fi
