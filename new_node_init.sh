#! /usr/bin/env bash

npm install -g bower
npm install -g broccoli-cli
npm install -g csslint
npm install -g elm-oracle
npm install -g htmlhint
npm install -g npm
npm install -g prettier
npm install -g stylelint
npm install -g tern
npm install -g yarn

( export PKG=eslint-config-airbnb; npm info "$PKG@latest" peerDependencies --json | command sed 's/[\{\},]//g ; s/: /@/g' | xargs npm install -g "$PKG@latest" )

# Hadolint
# YouCompleteMe
# stack install hdevtools
# stack install hlint
# stack install ShellCheck

sudo apt-get install tidy
