#!/usr/bin/env bash
set -e

if ! fc-list --format '%{postscriptname}\n' | grep -qx 'SymbolsNFM'; then
  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    curl -fsSL -o "$tmp/NerdFontsSymbolsOnly.zip" \
        "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VERSION}/NerdFontsSymbolsOnly.zip"
    unzip -q "$tmp/NerdFontsSymbolsOnly.zip" -d "$tmp/SymbolsOnly"
    mkdir -p ~/.local/share/fonts
    cp "$tmp"/SymbolsOnly/*.ttf ~/.local/share/fonts/
    fc-cache -f
  )
fi
