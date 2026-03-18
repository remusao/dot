#!/usr/bin/env bash

set -e

NEEDS_BUILD="0"
if ! [ -f "${HOME}/.local/bin/hadolint" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$("${HOME}/.local/bin/hadolint" --version)
  if [ "${CURRENT_VERSION}" != "Haskell Dockerfile Linter ${HADOLINT#v}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    tmp=$(mktemp "${HOME}/.local/bin/.hadolint.XXXXXX")
    trap 'rm -f "$tmp"' EXIT
    curl -fL "https://github.com/hadolint/hadolint/releases/download/${HADOLINT}/hadolint-Linux-x86_64" \
      -o "$tmp"
    chmod 755 "$tmp"
    mv "$tmp" "${HOME}/.local/bin/hadolint"
  )
fi
