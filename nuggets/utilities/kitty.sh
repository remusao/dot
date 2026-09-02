#!/usr/bin/env bash

set -e

. "$(dirname "${BASH_SOURCE[0]}")/../lib/verify.sh"

NEEDS_BUILD="0"
if ! [ -x "${HOME}/.local/bin/kitty" ]; then
  NEEDS_BUILD="1"
else
  # Never fatal: a kitty whose libpython vanished dies at exec, and that has to
  # force a rebuild rather than abort update.sh on a failed substitution.
  CURRENT_VERSION=$("${HOME}/.local/bin/kitty" --version 2>/dev/null | awk '{print $2}' || true)
  if [ "${CURRENT_VERSION}" != "${KITTY_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
  # --version answers from a compile-time constant, so an install cut short
  # (bin/ is copied before lib/) still reports the pinned version.
  if ! [ -d "${HOME}/.local/lib/kitty" ]; then
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
    libsimde-dev golang-go gnupg \
    python3-sphinx python3-sphinx-copybutton python3-sphinx-inline-tabs \
    python3-sphinxext-opengraph furo

  # Resolved here because the build subshell cds into its temp dir.
  KITTY_KEY=$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/../lib/keys/kovidgoyal.asc")

  (
    TEMP=$(mktemp -d)
    trap 'rm -rf "$TEMP"' EXIT
    git clone --depth=1 --branch "v${KITTY_VERSION}" \
      https://github.com/kovidgoyal/kitty.git "${TEMP}/src"
    cd "${TEMP}/src"

    # TLS only proves we reached github: a hijacked account or terminating
    # proxy could still hand us C and Go we then compile as us. Tags are signed
    # by Kovid Goyal; the key is pinned here so no second host is trusted.
    verify_git_tag "v${KITTY_VERSION}" "${KITTY_KEY}" \
      3CE1780F78DD88DF45194FD706BC317B515ACE7C

    # Native CPU optimization for Strix Halo (Zen 5, AVX-512 supported).
    export CFLAGS="-O3 -march=native -mtune=native -flto -pipe -fno-plt"
    export LDFLAGS="-Wl,-O1,--as-needed -flto"
    export CGO_CFLAGS="-O3 -march=native -mtune=native"
    export GOAMD64=v4
    # apt's golang-go is only the bootstrap; go.mod wants newer, fetched on demand.
    export GOTOOLCHAIN=auto

    # /usr/bin/python3, not pyenv's: setup.py bakes the running interpreter's
    # sysconfig rpath into the binary, which the next PYTHON_VERSION bump orphans.
    # Staged into a temp prefix because copy_man_pages() rmtree's
    # <prefix>/share/man/man{1,5} -- aimed at ~/.local it ate alacritty's pages.
    # Only the relative ../lib/kitty is baked in, so the tree relocates.
    # --update-check-interval=0 bakes the disabled update check into
    # kitty/options/types.py (defence in depth — config alone could be lost).
    /usr/bin/python3 setup.py linux-package \
      --prefix="${TEMP}/pkg" \
      --update-check-interval=0

    # Prune what setup.py used to; unlinking also dodges ETXTBSY on a live kitty.
    rm -rf "${HOME}/.local/lib/kitty" "${HOME}/.local/share/doc/kitty/html"
    rm -f "${HOME}/.local/bin/kitty" "${HOME}/.local/bin/kitten"
    cp -a "${TEMP}/pkg/." "${HOME}/.local/"
  )
fi
