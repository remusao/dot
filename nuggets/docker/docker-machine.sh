#!/usr/bin/env sh

set -e

NEEDS_BUILD="0"
if ! [ -f "/home/remi/.local/bin/docker-machine" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$(docker-machine --version | cut -d',' -f -1)
  if [ "${CURRENT_VERSION}" != "docker-machine version ${DOCKER_MACHINE}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  curl -L "https://github.com/docker/machine/releases/download/v0.16.0/docker-machine-$(uname -s)-$(uname -m)" -o ~/.local/bin/docker-machine
  chmod 755 ~/.local/bin/docker-machine
fi
