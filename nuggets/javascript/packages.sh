#!/usr/bin/env bash

set -e

# npm itself is pinned too; `npm@latest` would float against the locked tree below.
if [ "$(npm --version)" != "${NPM_VERSION}" ]; then
  npm install -g --ignore-scripts "npm@${NPM_VERSION}"
fi

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
  # --ignore-scripts here, not in an unmanaged ~/.npmrc, so the hardening travels
  # with the repo. The lockfile's sha512s prove the tarballs match what git
  # recorded, not that the registry ever signed them -- hence `audit signatures`.
  ( cd "${TOOLS_DIR}" && npm ci --ignore-scripts && npm audit signatures )

  echo "${LOCK_HASH}" > "${STAMP}"
fi

# Expose only the binaries we use (skip transitive tool bins to keep ~/.local/bin
# clean). prettier-plugin-svelte ships no bin -- prettier loads it from the tree.
# Outside the stamp guard: a wiped ~/.local/bin would otherwise never be repaired.
mkdir -p "${HOME}/.local/bin"
for b in vtsls bash-language-server svelteserver yaml-language-server \
         tsc tsserver prettier svelte-check stylelint svgo docker-langserver; do
  link="${HOME}/.local/bin/${b}"
  if [ -e "${TOOLS_DIR}/node_modules/.bin/${b}" ]; then
    ln -sf "${TOOLS_DIR}/node_modules/.bin/${b}" "${link}"
  else
    # A bin can vanish upstream (typescript 7 dropped `tsserver`). Drop the link
    # rather than leave it dangling, but only ours -- never another nugget's.
    echo "packages.sh: WARNING: ${b} is not in the locked tree" >&2
    case "$(readlink "${link}" 2>/dev/null)" in
      "${TOOLS_DIR}"/*) rm -f "${link}" ;;
    esac
  fi
done

# Drop the legacy nvm globals: zshrc puts nvm's bin dir AHEAD of ~/.local/bin, so
# a leftover global silently shadows the locked copy.
NPM_G="$(npm root -g)"
STALE=""
for p in bash-language-server dockerfile-language-server-nodejs neovim prettier \
         prettier-plugin-svelte pyright stylelint svelte svelte-check \
         svelte-language-server svgo typescript typescript-language-server \
         @vtsls/language-server yaml-language-server; do
  if [ -e "${NPM_G}/${p}" ]; then STALE="${STALE} ${p}"; fi
done
if [ -n "${STALE}" ]; then
  echo "packages.sh: removing shadowing nvm globals:${STALE}"
  # shellcheck disable=SC2086  # deliberate word splitting: one npm call, N names
  npm uninstall -g ${STALE}
fi
