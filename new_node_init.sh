#! /usr/bin/env bash

npm install -g \
    broccoli-cli \
    csslint \
    elm-oracle \
    htmlhint \
    npm \
    prettier \
    stylelint \
    tern \
    tslib \
    tslint \
    typescript \
    yarn \
    eslint-plugin-class-property \
    babel-eslint

( export PKG=eslint-config-airbnb; npm info "$PKG@latest" peerDependencies --json | command sed 's/[\{\},]//g ; s/: /@/g' | xargs npm install -g "$PKG@latest" )

# Hadolint
# YouCompleteMe
# stack install hdevtools
# stack install hlint
# stack install ShellCheck

sudo apt-get install tidy

# For pyenv
# libssl-dev
# zlib1g-dev
# libbz2-dev
# libreadline-dev
# libsqlite3-dev
# wget
# curl
# llvm
# libncurses5-dev
# libncursesw5-dev
