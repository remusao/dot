#! /usr/bin/env bash

# TODO - update apt packages
# TODO - install Node.js to latest

npm install -g npm@latest yarn@latest
( export PKG=eslint-config-airbnb; npm info "$PKG@latest" peerDependencies --json | command sed 's/[\{\},]//g ; s/: /@/g' | xargs npm install -g "$PKG@latest" )
npm install -g          \
  alex                  \
  babel-eslint@latest   \
  csslint@latest        \
  htmlhint@latest       \
  jshint@latest         \
  jsvu@latest           \
  neovim@latest         \
  npm@latest            \
  prettier@latest       \
  sass-lint@latest      \
  stylelint@latest      \
  svgo@latest           \
  tslib@latest          \
  tslint@latest         \
  typescript@latest

rustup update

# rustup component add rls-preview rust-analysis rust-src rustfmt

cargo install           \
  alacritty             \
  chars                 \
  du-dust               \
  eva                   \
  exa                   \
  fd-find               \
  hyperfine             \
  mdcat                 \
  ripgrep               \
  skim                  \
  titlecase             \
  watchexec

# TODO install from release?
# No binaries?
# dot

# TODO install Go binaries
# podman + restic?

# TODO - install editor config
