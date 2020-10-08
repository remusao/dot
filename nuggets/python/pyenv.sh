#!/usr/bin/env sh

set -e

if ! [ -d "${HOME}/.pyenv" ]; then
  git clone https://github.com/pyenv/pyenv.git ~/.pyenv
else
  (
    cd ~/.pyenv
    git pull origin master
  )
fi
