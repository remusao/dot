#!/usr/bin/env bash

set -e

. "$(dirname "${BASH_SOURCE[0]}")/../lib/verify.sh"

# kitty 0.49 rewrote its shaders in slang: slangc compiles them at package time,
# so this has to land before nuggets/utilities/kitty.sh, and again at runtime for
# custom shaders, so it cannot just live in kitty's build directory. Not packaged
# for noble (Arch has one); upstream's tarballs are the only Linux binaries.
#
# slang ships as a tree (bin/slangc plus the libslang*.so it finds through an
# $ORIGIN/../lib rpath and a 6MB standard module), so extract under
# ~/.local/share and symlink only the compiler: glibc expands $ORIGIN from the
# resolved path, so the symlink still reaches the libraries.
INSTALL_DIR="${HOME}/.local/share/slang"

NEEDS_BUILD="0"
if ! [ -x "${INSTALL_DIR}/bin/slangc" ]; then
  NEEDS_BUILD="1"
# slangc answers -version on stderr, hence 2>&1 and not the usual 2>/dev/null:
# reading stdout leaves this empty and refetches 24MB every run. -Fxq rather
# than a string compare so a future warning line on stderr is not a "mismatch",
# and so a tree too broken to answer reinstalls instead of aborting the run.
elif ! "${INSTALL_DIR}/bin/slangc" -version 2>&1 | grep -Fxq -- "${SLANG_VERSION}"; then
  NEEDS_BUILD="1"
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    # Stage beside the target: same-filesystem rename, and nothing reaps
    # ~/.local/share (hence the sweep). The tarball has no top-level directory,
    # so extracting into INSTALL_DIR directly would leave a half tree that the
    # check above then accepts.
    mkdir -p "${HOME}/.local/share"
    rm -rf "${HOME}"/.local/share/.slang.*
    tmp=$(mktemp -d "${HOME}/.local/share/.slang.XXXXXX")
    trap 'rm -rf "$tmp"' EXIT

    # The glibc-2.28 asset, not the plain linux-x86_64 one kitty's own CI takes:
    # that one also carries libslang-llvm.so for the host-CPU targets, 217MB
    # installed against 76MB, and kitty only ever asks for -target spirv/glsl.
    pkg="slang-${SLANG_VERSION}-linux-x86_64-glibc-2.28.tar.gz"
    curl_fetch \
      "https://github.com/shader-slang/slang/releases/download/v${SLANG_VERSION}/${pkg}" \
      "${tmp}/${pkg}"

    # Upstream signs nothing, so the digest pinned beside the version is the
    # only thing tying this to the bytes that were reviewed -- and it has to be
    # checked before the tarball is unpacked and run, not after.
    verify_sha256_pinned "${tmp}/${pkg}" "${SLANG_SHA256}"

    mkdir -p "${tmp}/tree"
    tar -xzf "${tmp}/${pkg}" -C "${tmp}/tree"

    # -version would only prove the binary starts. Compiling proves the standard
    # module and the SPIR-V backend survived the extract too -- a truncated tree
    # otherwise fails minutes into kitty's build instead of here.
    printf '[shader("compute")]\n[numthreads(1,1,1)]\nvoid main() {}\n' >"${tmp}/probe.slang"
    "${tmp}/tree/bin/slangc" -target spirv -o "${tmp}/probe.spv" "${tmp}/probe.slang"

    rm -rf "${INSTALL_DIR}"
    mv "${tmp}/tree" "${INSTALL_DIR}"
  )
fi

# mkdir because update.sh also runs standalone, where install.sh has not created
# ~/.local/bin yet and ln would abort the whole run. Unconditional because the
# check above only inspects the tree: a deleted symlink -- which is all kitty
# resolves -- would otherwise never be repaired.
mkdir -p "${HOME}/.local/bin"
ln -sf "${INSTALL_DIR}/bin/slangc" "${HOME}/.local/bin/slangc"
