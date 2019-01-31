#! /usr/bin/env bash

npm install -g \
    broccoli-cli@latest \
    csslint@latest \
    elm-oracle@latest \
    htmlhint@latest \
    npm@latest \
    prettier@latest \
    stylelint@latest \
    sass-lint@latest \
    tern@latest \
    tslib@latest \
    tslint@latest \
    typescript@latest \
    yarn@latest \
    eslint-plugin-class-property@latest \
    babel-eslint@latest \
    javascript-typescript-langserver@latest \
    dockerfile-language-server-nodejs@latest \
    neovim@latest \
    typescript-tslint-plugin@latest \
    jsvu@latest

( export PKG=eslint-config-airbnb; npm info "$PKG@latest" peerDependencies --json | command sed 's/[\{\},]//g ; s/: /@/g' | xargs npm install -g "$PKG@latest" )

cargo install rls ripgrep --force

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
