#!/usr/bin/env sh

set -e

NEEDS_BUILD="0"
if ! [ -f "/home/remi/.local/bin/nvim" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$(nvim --version | head -n 1)
  if [ "${CURRENT_VERSION}" != "NVIM ${NEOVIM}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  # Build deps
  sudo apt-get install --yes \
    autoconf \
    automake \
    cmake \
    g++ \
    gettext \
    gperf \
    libjemalloc-dev \
    libluajit-5.1-dev \
    libmsgpack-dev \
    libtermkey-dev \
    libtool \
    libtool-bin \
    libunibilium-dev \
    libvterm-dev \
    lua-bitop \
    lua-lpeg \
    lua-mpack \
    lua5.1 \
    ninja-build \
    pkg-config \
    unzip

  TEMP=/tmp/neovim
  (
    rm -fr "${TEMP}"
    mkdir "${TEMP}"
    git clone --depth=1 --branch "${NEOVIM}" git@github.com:neovim/neovim.git "${TEMP}"
    cd "${TEMP}" || exit 1

    make -j8 CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=/home/remi/.local" CMAKE_BUILD_TYPE=Release
    make install
    rm -fr "${TEMP}"
  )
fi
