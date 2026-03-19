#!/usr/bin/env bash

set -e

NEEDS_BUILD="0"
if ! [ -f "${HOME}/.local/bin/aws-vault" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$("${HOME}/.local/bin/aws-vault" --version 2>&1)
  if [ "${CURRENT_VERSION}" != "${AWS_VAULT_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    tmp=$(mktemp "${HOME}/.local/bin/.aws-vault.XXXXXX")
    trap 'rm -f "$tmp"' EXIT
    curl -fL "https://github.com/99designs/aws-vault/releases/download/${AWS_VAULT_VERSION}/aws-vault-linux-amd64" \
      -o "$tmp"
    chmod 755 "$tmp"
    mv "$tmp" "${HOME}/.local/bin/aws-vault"
  )
fi
