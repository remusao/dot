#! /usr/bin/env bash

npm install -g npm@latest yarn@latest
npm install -g \
  alex \
  babel-eslint@latest \
  broccoli-cli@latest \
  csslint@latest \
  dockerfile-language-server-nodejs@latest \
  elm-oracle@latest \
  eslint-plugin-class-property@latest \
  eslint_d@latest \
  htmlhint@latest \
  javascript-typescript-langserver@latest \
  jshint@latest \
  jsvu@latest \
  neovim@latest \
  prettier@latest \
  sass-lint@latest \
  stylelint@latest \
  svgo@latest \
  tern@latest \
  tslib@latest \
  tslint@latest \
  typescript-tslint-plugin@latest \
  typescript@latest \
  web-ext@latest

( export PKG=eslint-config-airbnb; npm info "$PKG@latest" peerDependencies --json | command sed 's/[\{\},]//g ; s/: /@/g' | xargs npm install -g "$PKG@latest" )

rustup update

rustup component add \
  cargo \
  clippy \
  rls \
  rust-analysis \
  rust-docs \
  rust-src \
  rust-std \
  rustfmt

cargo install \
  alacritty \
  chars \
  du-dust \
  eva \
  exa \
  fd-find \
  hyperfine \
  mdcat \
  ripgrep \
  skim \
  titlecase \
  watchexec
