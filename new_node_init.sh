#! /usr/bin/env bash

npm install -g npm
npm install -g yarn
npm install -g elm-oracle
npm install -g bower
npm install -g tern
npm install -g broccoli-cli
( export PKG=eslint-config-airbnb; npm info "$PKG@latest" peerDependencies --json | command sed 's/[\{\},]//g ; s/: /@/g' | xargs npm install -g "$PKG@latest" )
