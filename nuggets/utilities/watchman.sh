#!/usr/bin/env bash

set -e

NEEDS_BUILD="0"
if ! command -v watchman &>/dev/null; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$(watchman version 2>/dev/null | jq -r '.version' 2>/dev/null || echo "")
  if [ "${CURRENT_VERSION}" != "${WATCHMAN_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    curl -fL "https://github.com/facebook/watchman/releases/download/v${WATCHMAN_VERSION}/watchman-v${WATCHMAN_VERSION}-linux.zip" \
      -o "${tmp}/watchman.zip"
    unzip -q "${tmp}/watchman.zip" -d "${tmp}"
    sudo mkdir -p /usr/local/{bin,lib}
    sudo cp "${tmp}"/watchman-*/bin/watchman /usr/local/bin/
    sudo cp "${tmp}"/watchman-*/lib/* /usr/local/lib/ 2>/dev/null || true
    sudo chmod 755 /usr/local/bin/watchman
  )
fi
