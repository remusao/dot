#!/usr/bin/env sh

set -e

NEEDS_BUILD="0"
if ! [ -f "/home/remi/.local/bin/vagrant" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$(vagrant --version)
  if [ "${CURRENT_VERSION}" != "Vagrant ${VAGRANT}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  curl -L "https://releases.hashicorp.com/vagrant/${VAGRANT}/vagrant_${VAGRANT}_linux_amd64.zip" -o vagrant.zip
  unzip vagrant.zip
  mv vagrant ~/.local/bin/vagrant
  rm -frv vagrant.zip
  chmod 755 ~/.local/bin/vagrant
fi
