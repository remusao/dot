# https://nodejs.org/dist/index.json -- LTS line only (24.x).
# Do not repoint at nodejs/node: releases/latest there is Current, not LTS.
export NODEJS_VERSION="24.20.0"

# https://registry.npmjs.org/npm -- dist-tags.latest; npm/cli is a monorepo, so its releases are not npm versions.
export NPM_VERSION="12.0.2"

# https://github.com/neovim/neovim/releases/latest
export NEOVIM_VERSION="v0.12.5"

# https://www.python.org/downloads/
export PYTHON_VERSION="3.12.14"

# Not PYENV_VERSION: pyenv reads that to pick the active Python, and zshrc sources this file everywhere.
# https://github.com/pyenv/pyenv/releases/latest
export PYENV_RELEASE="v2.8.5"

# Not RUSTUP_VERSION: live rustup env var, makes `rustup self update` refuse to move.
# https://github.com/rust-lang/rustup/tags
export RUSTUP_PIN="1.29.1" # bootstrap only; `rustup self update` moves past it

# crates.io: ripgrep
export RIPGREP_VERSION="15.2.0"

# crates.io: sccache
export SCCACHE_VERSION="0.17.0"

# https://github.com/hadolint/hadolint/releases/latest (asset: ^hadolint-linux-x86_64$ ^checksums\.sha256$)
export HADOLINT_VERSION="v2.15.1"

# https://github.com/nvm-sh/nvm/releases/latest
export NVM_VERSION="v0.40.7"

# https://github.com/restic/restic/releases/latest (asset: _linux_amd64\.bz2$ ^SHA256SUMS$)
export RESTIC_VERSION="0.19.1"

# https://github.com/rclone/rclone/releases/latest (asset: -linux-amd64\.zip$ ^SHA256SUMS$)
export DOTFILES_RCLONE_VERSION="v1.75.0"

# https://github.com/netblue30/firejail/releases/latest (asset: ^firejail_[0-9.]+_1_amd64\.deb$ ^firejail-[0-9.]+\.asc$)
export FIREJAIL_VERSION="0.9.80"

# https://github.com/obsidianmd/obsidian-releases/releases/latest (asset: amd64\.deb$)
export OBSIDIAN_VERSION="1.13.7"

# https://github.com/ByteNess/aws-vault/releases/latest (asset: ^aws-vault-linux-amd64$ ^aws-vault_sha256_checksums\.txt$)
export AWS_VAULT_VERSION="v7.13.6"

# Verifier for sops' sigstore-signed checksum manifest (nuggets/utilities/cosign.sh).
# https://github.com/sigstore/cosign/releases/latest (asset: ^cosign-linux-amd64$ ^cosign_checksums\.txt$)
export COSIGN_VERSION="v3.1.3"

# https://github.com/getsops/sops/releases/latest (asset: \.linux\.amd64$ \.checksums\.txt$)
export SOPS_VERSION="v3.13.3"

# crates.io: cargo-audit
export CARGO_AUDIT_VERSION="0.22.2"

# crates.io: cargo-deny
export CARGO_DENY_VERSION="0.20.2"

# crates.io: cargo-fuzz
export CARGO_FUZZ_VERSION="0.13.2"

# crates.io: flamegraph
export FLAMEGRAPH_VERSION="0.6.14"

# crates.io: loc
export LOC_VERSION="0.5.0"

# crates.io: oxipng
export OXIPNG_VERSION="10.2.0"

# crates.io: tokei
export TOKEI_VERSION="14.0.0"

# crates.io: tree-sitter-cli
export TREE_SITTER_CLI_VERSION="0.27.0"

# crates.io: eza
export EZA_VERSION="0.23.5"

# crates.io: du-dust
export DU_DUST_VERSION="1.2.5"

# crates.io: difftastic
export DIFFTASTIC_VERSION="0.70.0"

# https://github.com/jesseduffield/lazygit/releases/latest (asset: _linux_x86_64\.tar\.gz$ ^checksums\.txt$)
export LAZYGIT_VERSION="0.64.1"

# https://github.com/facebook/watchman/releases/latest (asset: linux\.zip$)
export WATCHMAN_VERSION="2026.07.27.00"

# https://github.com/alacritty/alacritty/releases/latest
export ALACRITTY_VERSION="0.17.0"

# https://rubygems.org/gems/fusuma -- a gem, not a GitHub release; bump.sh can only warn.
export FUSUMA_VERSION="3.12.0"

# crates.io: i3status-rs
export I3STATUS_RUST_VERSION="0.36.1"

# https://github.com/romkatv/powerlevel10k-media -- no releases at all, so the commit is the pin.
export MESLO_NF_COMMIT="145eb9fbc2f42ee408dacd9b22d8e6e0e553f83d"

# https://github.com/powerline/fonts -- newest tag is from 2015; same, pinned by commit.
export POWERLINE_FONTS_COMMIT="a029626780dd4af32f15a3e708a5b00528c22f1d"

# https://github.com/ryanoasis/nerd-fonts/releases/latest (asset: ^NerdFontsSymbolsOnly\.zip$ ^JetBrainsMono\.tar\.xz$ ^SHA-256\.txt$)
export NERD_FONTS_VERSION="v3.5.1"

# https://github.com/FortAwesome/Font-Awesome/releases (asset: -desktop\.zip$)
export FONT_AWESOME_VERSION="7.3.1"

# https://git.sr.ht/~steef/snixembed/refs
export SNIXEMBED_VERSION="0.3.3"

# The commit SNIXEMBED_VERSION resolves to -- bump together; sr.ht tags are mutable.
export SNIXEMBED_COMMIT="6025cc7257d3f8cc245a538b8e2c4d117d9e4bed"

# https://github.com/junegunn/fzf/releases/latest (asset: _amd64\.deb$ _checksums\.txt$)
export FZF_VERSION="0.74.3"

# https://github.com/sharkdp/fd/releases/latest (asset: -x86_64-unknown-linux-gnu\.tar\.gz$)
export FD_VERSION="10.5.0"

# https://github.com/sharkdp/bat/releases/latest (asset: -x86_64-unknown-linux-gnu\.tar\.gz$)
export BAT_VERSION="0.26.1"

# https://github.com/dandavison/delta/releases/latest (asset: -x86_64-unknown-linux-gnu\.tar\.gz$)
export DELTA_VERSION="0.19.2"

# https://github.com/sharkdp/hyperfine/releases/latest (asset: -x86_64-unknown-linux-musl\.tar\.gz$)
export HYPERFINE_VERSION="1.20.0"

# https://github.com/kovidgoyal/kitty/releases/latest
export KITTY_VERSION="0.48.2"

# https://github.com/LuaLS/lua-language-server/releases/latest (asset: -linux-x64\.tar\.gz$)
export LUA_LANGUAGE_SERVER_VERSION="3.19.1"

# https://github.com/mvdan/sh/releases/latest (shfmt) (asset: _linux_amd64$)
export SHFMT_VERSION="v3.14.0"

# https://github.com/JohnnyMorganz/StyLua/releases/latest (asset: ^stylua-linux-x86_64\.zip$)
export STYLUA_VERSION="v2.5.2"

# https://github.com/zsh-users/zsh-syntax-highlighting/tags
export ZSH_SYNTAX_HIGHLIGHTING_VERSION="0.8.0"
