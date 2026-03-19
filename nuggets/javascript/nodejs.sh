#!/usr/bin/env bash

set -e

if [ ! -d "${HOME}/.nvm" ]; then
  curl -fo- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
fi

export TMPDIR="${TMPDIR:-/tmp}"
. "${HOME}/.nvm/nvm.sh"
nvm install "${NODEJS_VERSION}"
