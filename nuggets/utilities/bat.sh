#!/usr/bin/env bash

set -e

. "$(dirname "${BASH_SOURCE[0]}")/../lib/verify.sh"

# Man page and completion are guarded too; nothing else restores them.
NEEDS_BUILD="0"
if ! [ -x "${HOME}/.local/bin/bat" ] ||
  ! [ -f "${HOME}/.local/share/man/man1/bat.1" ] ||
  ! [ -f "${HOME}/.zsh_functions/_bat" ]; then
  NEEDS_BUILD="1"
else
  # An unrunnable binary should reinstall, not abort the run on a failed probe.
  CURRENT_VERSION=$("${HOME}/.local/bin/bat" --version 2>/dev/null | awk '{print $2}') || CURRENT_VERSION=""
  if [ "${CURRENT_VERSION}" != "${BAT_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT

    # gnu not musl: musl's allocator is slower on the fzf CTRL-T preview path.
    # Upstream ships no checksums or signatures, so TLS is the only integrity.
    pkg="bat-v${BAT_VERSION}-x86_64-unknown-linux-gnu"
    curl_fetch \
      "https://github.com/sharkdp/bat/releases/download/v${BAT_VERSION}/${pkg}.tar.gz" \
      "${tmp}/bat.tar.gz"
    tar -xzf "${tmp}/bat.tar.gz" -C "$tmp"
    chmod 755 "${tmp}/${pkg}/bat"
    mv "${tmp}/${pkg}/bat" "${HOME}/.local/bin/bat"

    # _bat goes to ~/.zsh_functions, which zshrc puts on fpath.
    install -Dm644 "${tmp}/${pkg}/autocomplete/bat.zsh" "${HOME}/.zsh_functions/_bat"
    install -Dm644 "${tmp}/${pkg}/bat.1" "${HOME}/.local/share/man/man1/bat.1"
  )
fi
