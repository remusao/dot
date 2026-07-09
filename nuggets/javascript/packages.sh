#!/usr/bin/env bash

set -e

# Keep npm itself current (nvm's npm).
npm install -g npm@latest

# --- Node-based language servers & tools, locked via package-lock.json ---------
# Installed with `npm ci` from the committed lockfile: the ENTIRE dependency tree
# is version-pinned and SHA-512 integrity-verified (supply-chain hardening + fully
# reproducible), instead of `npm -g @latest` which floats versions with no lock.
# Only the binaries we actually use are symlinked onto PATH.
# To bump: edit nuggets/javascript/package.json, run `npm install` in that dir,
# and commit the regenerated package-lock.json.
SRC_DIR="nuggets/javascript"                       # committed manifest (CWD = repo root)
TOOLS_DIR="${HOME}/.local/lib/nvim-node-tools"
STAMP="${TOOLS_DIR}/.installed-lock.sha256"
LOCK_HASH="$(sha256sum "${SRC_DIR}/package-lock.json" | awk '{print $1}')"

if [ ! -f "${STAMP}" ] || [ "$(cat "${STAMP}" 2>/dev/null)" != "${LOCK_HASH}" ]; then
  mkdir -p "${TOOLS_DIR}"
  cp "${SRC_DIR}/package.json" "${SRC_DIR}/package-lock.json" "${TOOLS_DIR}/"
  ( cd "${TOOLS_DIR}" && npm ci )

  # Expose only the binaries we use (skip transitive tool bins to keep ~/.local/bin
  # clean). prettier-plugin-svelte ships no bin -- prettier loads it from the tree.
  for b in vtsls bash-language-server svelteserver yaml-language-server \
           tsc tsserver prettier svelte-check stylelint svgo docker-langserver; do
    if [ -e "${TOOLS_DIR}/node_modules/.bin/${b}" ]; then
      ln -sf "${TOOLS_DIR}/node_modules/.bin/${b}" "${HOME}/.local/bin/${b}"
    fi
  done

  # One-time migration: drop the old per-package nvm globals so ONLY the locked
  # copies are on PATH (idempotent -- a no-op once they're gone).
  npm uninstall -g \
    bash-language-server dockerfile-language-server-nodejs neovim prettier \
    prettier-plugin-svelte pyright stylelint svelte svelte-check \
    svelte-language-server svgo typescript typescript-language-server \
    @vtsls/language-server yaml-language-server >/dev/null 2>&1 || true

  echo "${LOCK_HASH}" > "${STAMP}"
fi