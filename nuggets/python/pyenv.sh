#!/usr/bin/env bash

set -e

if [ ! -d "${HOME}/.pyenv" ]; then
  git clone https://github.com/pyenv/pyenv.git "${HOME}/.pyenv"
else
  (cd "${HOME}/.pyenv" && git pull --ff-only origin master)
fi
