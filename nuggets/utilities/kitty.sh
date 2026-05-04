#!/usr/bin/env bash

set -e

NEEDS_BUILD="0"
if ! [ -x "${HOME}/.local/bin/kitty" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$("${HOME}/.local/bin/kitty" --version | awk '{print $2}')
  if [ "${CURRENT_VERSION}" != "${KITTY_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  sudo apt-get install --yes \
    build-essential pkg-config python3 python3-dev \
    libharfbuzz-dev libcairo2-dev libdbus-1-dev libxxhash-dev \
    liblcms2-dev librsync-dev libfontconfig1-dev libfreetype-dev \
    libpng-dev zlib1g-dev libssl-dev libcanberra-dev \
    libxcursor-dev libxinerama-dev libxrandr-dev libxi-dev \
    libxkbcommon-dev libxkbcommon-x11-dev libx11-xcb-dev \
    libxcb-image0-dev libxcb-xkb-dev libxcb-render0-dev \
    libgl1-mesa-dev libegl1-mesa-dev libwayland-dev wayland-protocols \
    libsimde-dev golang-go \
    python3-sphinx python3-sphinx-copybutton python3-sphinx-inline-tabs \
    python3-sphinxext-opengraph furo

  (
    TEMP=$(mktemp -d)
    trap 'rm -rf "$TEMP"' EXIT
    git clone --depth=1 --branch "v${KITTY_VERSION}" \
      https://github.com/kovidgoyal/kitty.git "${TEMP}"
    cd "${TEMP}"

    # Native CPU optimization for Strix Halo (Zen 5, AVX-512 supported).
    export CFLAGS="-O3 -march=native -mtune=native -flto -pipe -fno-plt"
    export LDFLAGS="-Wl,-O1,--as-needed -flto"
    export CGO_CFLAGS="-O3 -march=native -mtune=native"
    export GOAMD64=v4

    # --update-check-interval=0 bakes the disabled update check into
    # kitty/options/types.py (defence in depth — config alone could be lost).
    python3 setup.py linux-package \
      --prefix="${HOME}/.local" \
      --update-check-interval=0
  )
fi
