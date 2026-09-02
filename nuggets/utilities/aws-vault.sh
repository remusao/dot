#!/usr/bin/env bash

set -e

. "$(dirname "${BASH_SOURCE[0]}")/../lib/verify.sh"

NEEDS_BUILD="0"
if ! [ -f "${HOME}/.local/bin/aws-vault" ]; then
  NEEDS_BUILD="1"
else
  # --version goes to stderr, hence 2>&1. Without `|| true` an unrunnable binary
  # (truncated, wrong arch) aborts update.sh before the reinstall below.
  CURRENT_VERSION=$("${HOME}/.local/bin/aws-vault" --version 2>&1 || true)
  if [ "${CURRENT_VERSION}" != "${AWS_VAULT_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    base="https://github.com/ByteNess/aws-vault/releases/download/${AWS_VAULT_VERSION}"
    tmp=$(mktemp "${HOME}/.local/bin/.aws-vault.XXXXXX")
    trap 'rm -f "$tmp"' EXIT

    # ByteNess signs nothing, so checksums.txt is all upstream offers here:
    # integrity, not provenance, on the binary holding our AWS credentials.
    fetch_verified "${base}/aws-vault-linux-amd64" "$tmp" \
      "${base}/aws-vault_sha256_checksums.txt" "aws-vault-linux-amd64"

    chmod 755 "$tmp" # mktemp made it 0600
    mv "$tmp" "${HOME}/.local/bin/aws-vault"
  )
fi
