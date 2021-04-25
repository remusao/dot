#!/usr/bin/env sh

set -e

NEEDS_BUILD="0"
if ! [ -f "/home/remi/.local/bin/keepassxc" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$(keepassxc --version)
  if [ "${CURRENT_VERSION}" != "KeePassXC ${KEEPASSXC}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  # Build deps
  sudo apt-get install --yes \
    asciidoctor \
    cmake \
    libarchive-dev \
    libargon2-dev \
    libgcrypt20-dev \
    libmicrohttpd-dev \
    libqrencode-dev \
    libqt5svg5-dev \
    libsodium-dev \
    libxi-dev \
    libxtst-dev \
    make \
    qtbase5-dev \
    qtbase5-private-dev \
    qttools5-dev \
    qttools5-dev-tools \
    zlib1g-dev

  TEMP=/tmp/keepassxc
  (
    rm -fr "${TEMP}"
    mkdir "${TEMP}"
    git clone --depth=1 --branch "${KEEPASSXC}" git@github.com:keepassxreboot/keepassxc.git "${TEMP}"
    cd "${TEMP}" || exit 1
    mkdir build
    cd build || exit 1

    cmake \
      -DCMAKE_BUILD_TYPE=Release \
      -DWITH_XC_AUTOTYPE=OFF \
      -DWITH_XC_YUBIKEY=ON \
      -DWITH_XC_BROWSER=OFF \
      -DWITH_XC_NETWORKING=OFF \
      -DWITH_XC_SSHAGENT=OFF \
      -DWITH_XC_TOUCHID=OFF \
      -DWITH_XC_FDOSECRETS=OFF \
      -DWITH_XC_KEESHARE=OFF \
      -DWITH_XC_KEESHARE_SECURE=OFF \
      -DWITH_XC_UPDATECHECK=OFF \
      -DWITH_TESTS=OFF \
      -DWITH_GUI_TESTS=OFF \
      -DWITH_DEV_BUILD=OFF \
      -DWITH_ASAN=OFF \
      -DWITH_COVERAGE=OFF \
      -DWITH_APP_BUNDLE=OFF \
      -DKEEPASSXC_DIST_TYPE="Other" \
      -G "Unix Makefiles" \
      -DCMAKE_INSTALL_PREFIX:PATH=/home/remi/.local ..

    make -j8
    make install
    rm -fr "${TEMP}"
  )
fi
