#!/usr/bin/env bash
set -e

if ! fc-list | grep -qi "Font Awesome 6 Free Solid"; then
  (
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    curl -fsSL -o "$tmp/fa.zip" \
        "https://github.com/FortAwesome/Font-Awesome/releases/download/${FONT_AWESOME_VERSION}/fontawesome-free-${FONT_AWESOME_VERSION}-desktop.zip"
    unzip -q "$tmp/fa.zip" -d "$tmp"
    cp "$tmp"/fontawesome-free-*/otfs/*.otf ~/.local/share/fonts/
    fc-cache -f
  )
fi
