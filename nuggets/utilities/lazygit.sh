#!/usr/bin/env bash

set -e

. "$(dirname "${BASH_SOURCE[0]}")/../lib/verify.sh"

NEEDS_BUILD="0"
if ! [ -x "${HOME}/.local/bin/lazygit" ]; then
  NEEDS_BUILD="1"
else
  # `--version` also lists `git version=`, so anchor the match to a field
  # boundary. Never fatal: a bad binary must reinstall, not abort the run.
  CURRENT_VERSION=$("${HOME}/.local/bin/lazygit" --version 2>/dev/null |
    grep -oP '(^|, )version=\K[^,]+' || true)
  if [ "${CURRENT_VERSION}" != "${LAZYGIT_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    base="https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}"
    # Lowercase: GitHub serves `Linux_` too, but checksums.txt lists only this.
    asset="lazygit_${LAZYGIT_VERSION}_linux_x86_64.tar.gz"
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    fetch_verified "${base}/${asset}" "${tmp}/${asset}" "${base}/checksums.txt" "$asset"
    tar -xzf "${tmp}/${asset}" -C "$tmp"
    chmod 755 "${tmp}/lazygit"
    mv "${tmp}/lazygit" "${HOME}/.local/bin/lazygit"
  )
fi
