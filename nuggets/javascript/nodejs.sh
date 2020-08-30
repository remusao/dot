#!/usr/bin/env sh

set -e

echo "> Updating Node.js ${NODEJS}"
. /home/remi/.nvm/nvm.sh
nvm install "${NODEJS}"
