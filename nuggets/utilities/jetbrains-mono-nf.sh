#!/usr/bin/env bash
set -e

if ! fc-list | grep -qi "JetBrainsMono Nerd Font"; then
  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    curl -fsSL -o "$tmp/JetBrainsMono.zip" \
        "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VERSION}/JetBrainsMono.zip"
    unzip -q "$tmp/JetBrainsMono.zip" -d "$tmp/JetBrainsMono"
    mkdir -p ~/.local/share/fonts
    cp "$tmp"/JetBrainsMono/*.ttf ~/.local/share/fonts/
    fc-cache -f
  )
fi
