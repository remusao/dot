#!/usr/bin/env bash

set -e

NEEDS_BUILD="0"
if ! [ -f "${HOME}/.local/bin/fzf" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$("${HOME}/.local/bin/fzf" --version | awk '{print $1}')
  if [ "${CURRENT_VERSION}" != "${FZF_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    curl -fL "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-linux_amd64.tar.gz" \
      -o "${tmp}/fzf.tar.gz"
    tar -xzf "${tmp}/fzf.tar.gz" -C "$tmp"
    chmod 755 "${tmp}/fzf"
    mv "${tmp}/fzf" "${HOME}/.local/bin/fzf"
  )
fi
