#!/usr/bin/env sh

set -e

if ! [ -d "/home/remi/.nvm" ]; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.2/install.sh | bash
fi

echo "> Updating Node.js ${NODEJS}"
. /home/remi/.nvm/nvm.sh
nvm install "${NODEJS}"
