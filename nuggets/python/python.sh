#!/usr/bin/env bash

set -e

NEEDS_BUILD="0"
if [ ! -d "${HOME}/.pyenv/versions/${PYTHON_VERSION}/" ]; then
  NEEDS_BUILD="1"
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  eval "$(${HOME}/.pyenv/bin/pyenv init -)"
  PYTHON_CONFIGURE_OPTS="--enable-optimizations --with-lto --enable-shared" \
  PYTHON_CFLAGS="-march=native" \
    pyenv install --force "${PYTHON_VERSION}"
fi
