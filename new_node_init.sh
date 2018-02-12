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
    yarn

( export PKG=eslint-config-airbnb; npm info "$PKG@latest" peerDependencies --json | command sed 's/[\{\},]//g ; s/: /@/g' | xargs npm install -g "$PKG@latest" )

# Hadolint
# YouCompleteMe
# stack install hdevtools
# stack install hlint
# stack install ShellCheck

sudo apt-get install tidy
