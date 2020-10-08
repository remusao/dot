#!/usr/bin/env sh

set -e

NEEDS_BUILD="0"
if ! [ -d "${HOME}/.pyenv/versions/${PYTHON}/" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$(python3 --version)
  if [ "${CURRENT_VERSION}" != "Python ${PYTHON}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  eval "$(pyenv init -)"
  CONFIGURE_OPTS="--enable-optimizations --with-lto --enable-shared" pyenv install --force "${PYTHON}"
fi
