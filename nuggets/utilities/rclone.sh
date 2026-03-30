#!/usr/bin/env bash

set -e

NEEDS_BUILD="0"
if ! [ -f "${HOME}/.local/bin/rclone" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$("${HOME}/.local/bin/rclone" version | awk 'NR==1{print $2}')
  if [ "${CURRENT_VERSION}" != "${DOTFILES_RCLONE_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    curl -fL "https://github.com/rclone/rclone/releases/download/${DOTFILES_RCLONE_VERSION}/rclone-${DOTFILES_RCLONE_VERSION}-linux-amd64.zip" \
      -o "${tmp}/rclone.zip"
    unzip -q "${tmp}/rclone.zip" -d "${tmp}"
    chmod 755 "${tmp}/rclone-${DOTFILES_RCLONE_VERSION}-linux-amd64/rclone"
    mv "${tmp}/rclone-${DOTFILES_RCLONE_VERSION}-linux-amd64/rclone" "${HOME}/.local/bin/rclone"
  )
fi
