#!/usr/bin/env sh

set -e

NEEDS_BUILD="0"
if ! [ -f "/home/remi/.local/bin/docker-compose" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$(docker-compose --version)
  if [ "${CURRENT_VERSION}" != "Docker Compose version ${DOCKER_COMPOSE}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE}/docker-compose-linux-x86_64" -o ~/.local/bin/docker-compose
  chmod 755 ~/.local/bin/docker-compose
fi
