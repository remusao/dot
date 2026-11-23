#!/usr/bin/env bash

set -e

. "$(dirname "${BASH_SOURCE[0]}")/../lib/verify.sh"

# Empty when uv is missing or cannot run: reinstall.
CURRENT_VERSION=$("${HOME}/.local/bin/uv" --version 2>/dev/null | awk '{print $2}') || CURRENT_VERSION=""
if [ "${CURRENT_VERSION}" != "${UV_VERSION}" ]; then
  (
    base="https://github.com/astral-sh/uv/releases/download/${UV_VERSION}"
    asset="uv-x86_64-unknown-linux-gnu.tar.gz"
    # In the destination dir so each mv is a same-filesystem rename(2).
    mkdir -p "${HOME}/.local/bin"
    tmp=$(mktemp -d "${HOME}/.local/bin/.uv.XXXXXX")
    trap 'rm -rf "$tmp"' EXIT
    fetch_verified "${base}/${asset}" "${tmp}/${asset}" "${base}/sha256.sum" "$asset"
    tar -xzf "${tmp}/${asset}" -C "$tmp" --strip-components=1
    mv "${tmp}/uv" "${tmp}/uvx" "${HOME}/.local/bin/"
  )
fi

# CLI tools, isolated venvs with entry points in ~/.local/bin. Pinned here (PyPI,
# which bump.sh does not query); a no-op when the pinned version is installed.
# Tool venvs carry CACHEDIR.TAG: a restic restore brings back the empty venv dir and
# dangling ~/.local/bin links, so --force whenever the venv has no python.
tool_dir=$("${HOME}/.local/bin/uv" tool dir)
for tool in awscli==1.45.29 check-jsonschema==0.38.0 jinjanator==25.3.1 maturin==1.12.6 ruff==0.15.1; do
  force=()
  [ -x "${tool_dir}/${tool%%==*}/bin/python" ] || force=(--force)
  "${HOME}/.local/bin/uv" tool install --quiet "${force[@]}" "$tool"
done
