#! /usr/bin/env bash

npm install -g \
    babel-eslint@latest \
    broccoli-cli@latest \
    csslint@latest \
    dockerfile-language-server-nodejs@latest \
    elm-oracle@latest \
    eslint-plugin-class-property@latest \
    eslint_d@latest \
    htmlhint@latest \
    javascript-typescript-langserver@latest \
    jsvu@latest \
    neovim@latest \
    npm@latest \
    prettier@latest \
    sass-lint@latest \
    stylelint@latest \
    tern@latest \
    tslib@latest \
    tslint@latest \
    typescript-tslint-plugin@latest \
    typescript@latest \
    web-ext@latest \
    yarn@latest

( export PKG=eslint-config-airbnb; npm info "$PKG@latest" peerDependencies --json | command sed 's/[\{\},]//g ; s/: /@/g' | xargs npm install -g "$PKG@latest" )

rustup component add \
    cargo \
    clippy \
    rls \
    rust-analysis \
    rust-docs \
    rust-src \
    rust-std \
    rustfmt

# cargo install ripgrep --force

# Hadolint
# YouCompleteMe
# stack install hdevtools
# stack install hlint
# stack install ShellCheck

# sudo apt-get install tidy
# editorconfig libeditorconfig-dev

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
