#!/usr/bin/env sh

set -e

NEEDS_BUILD="0"
if ! [ -f "/home/remi/.local/bin/haskell-language-server-wrapper" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$(haskell-language-server-wrapper --numeric-version)
  if [ "${CURRENT_VERSION}" != "${HASKELL_LANGUAGE_SERVER}.0" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  curl -L "https://github.com/haskell/haskell-language-server/releases/download/${HASKELL_LANGUAGE_SERVER}/haskell-language-server-wrapper-Linux.gz" -o ~/.local/bin/haskell-language-server-wrapper.gz
  (
    cd ~/.local/bin
    gunzip --force haskell-language-server-wrapper.gz
    chmod 755 haskell-language-server-wrapper
  )
fi
