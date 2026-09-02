#!/usr/bin/env bash

set -e

. "$(dirname "${BASH_SOURCE[0]}")/../lib/fonts.sh"
. "$(dirname "${BASH_SOURCE[0]}")/../lib/verify.sh"

if ! font_up_to_date nerd-fonts-symbols "${NERD_FONTS_VERSION}"; then
  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    # SHA-256.txt is the only integrity material the release ships; the sibling
    # jetbrains-mono-nf.sh already checks the same file.
    base="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VERSION}"
    fetch_verified "${base}/NerdFontsSymbolsOnly.zip" "$tmp/NerdFontsSymbolsOnly.zip" \
      "${base}/SHA-256.txt" NerdFontsSymbolsOnly.zip
    unzip -q "$tmp/NerdFontsSymbolsOnly.zip" -d "$tmp/SymbolsOnly"
    font_install "$tmp"/SymbolsOnly/*.ttf
  )
  font_stamp nerd-fonts-symbols "${NERD_FONTS_VERSION}"
fi
