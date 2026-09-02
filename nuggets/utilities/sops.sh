#!/usr/bin/env bash

set -e

. "$(dirname "${BASH_SOURCE[0]}")/../lib/verify.sh"

NEEDS_BUILD="0"
if ! [ -x "${HOME}/.local/bin/sops" ]; then
  NEEDS_BUILD="1"
else
  # sops 3.10 prints a deprecation notice on stdout ahead of the version line;
  # unanchored awk parses that, so the pin never matches and every run
  # re-downloads. NR==1 holds if SOPS_DISABLE_VERSION_CHECK goes away, and
  # `|| true` lets an unrunnable binary fall through to the reinstall below.
  CURRENT_VERSION=$(SOPS_DISABLE_VERSION_CHECK=true \
    "${HOME}/.local/bin/sops" --version 2>/dev/null |
    awk 'NR==1{print "v"$2}' || true)
  if [ "${CURRENT_VERSION}" != "${SOPS_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    base="https://github.com/getsops/sops/releases/download/${SOPS_VERSION}"
    asset="sops-${SOPS_VERSION}.linux.amd64"
    tmp=$(mktemp "${HOME}/.local/bin/.sops.XXXXXX")
    trap 'rm -f "$tmp"' EXIT

    # This binary decrypts the machine's secrets, so the manifest is checked for
    # provenance, not merely integrity: the identity flags bind the keyless
    # sigstore bundle to sops' release workflow -- without them cosign accepts a
    # bundle signed by anybody. No quiet flag, so its stderr is shown on failure.
    work=$(mktemp -d)
    trap 'rm -f "$tmp"; rm -rf "$work"' EXIT
    sums="sops-${SOPS_VERSION}.checksums.txt"
    curl_fetch "${base}/${sums}" "${work}/${sums}"
    curl_fetch "${base}/sops-${SOPS_VERSION}.checksums.sigstore.json" "${work}/bundle.json"
    if ! "${HOME}/.local/bin/cosign" verify-blob --bundle "${work}/bundle.json" \
      --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
      --certificate-identity-regexp='^https://github\.com/getsops/sops/' \
      "${work}/${sums}" >/dev/null 2>"${work}/cosign.err"; then
      cat "${work}/cosign.err" >&2
      printf 'sops: cosign could not verify %s -- bad manifest, or sigstore TUF\n' "${SOPS_VERSION}" >&2
      printf '      metadata (tuf-repo-cdn.sigstore.dev) unreachable\n' >&2
      exit 1
    fi

    curl_fetch "${base}/${asset}" "$tmp"
    verify_sha256 "$tmp" "${work}/${sums}" "$asset"

    chmod 755 "$tmp" # mktemp made it 0600
    mv "$tmp" "${HOME}/.local/bin/sops"
  )
fi
