#!/usr/bin/env bash

set -e

. "$(dirname "${BASH_SOURCE[0]}")/../lib/fonts.sh"
. "$(dirname "${BASH_SOURCE[0]}")/../lib/verify.sh"

if ! font_up_to_date jetbrains-mono-nf "${NERD_FONTS_VERSION}"; then
  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT

    # The .tar.xz and .zip carry identical trees; the xz is 7 MB against 134 MB.
    # SHA-256.txt is the only integrity material the release ships (no .asc, no
    # attestation).
    fetch_verified \
      "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VERSION}/JetBrainsMono.tar.xz" \
      "$tmp/JetBrainsMono.tar.xz" \
      "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VERSION}/SHA-256.txt" \
      JetBrainsMono.tar.xz

    # tar will not create its destination.
    mkdir -p "$tmp/JetBrainsMono"
    tar -xJf "$tmp/JetBrainsMono.tar.xz" -C "$tmp/JetBrainsMono"
    font_install "$tmp"/JetBrainsMono/*.ttf
  )
  font_stamp jetbrains-mono-nf "${NERD_FONTS_VERSION}"
fi
