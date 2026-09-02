#!/usr/bin/env bash

set -e

. "$(dirname "${BASH_SOURCE[0]}")/../lib/verify.sh"

NEEDS_BUILD="0"
if ! command -v firejail &>/dev/null; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$(firejail --version 2>/dev/null | head -1 | grep -oP '[\d.]+') ||
    CURRENT_VERSION=""
  if [ "${CURRENT_VERSION}" != "${FIREJAIL_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    base="https://github.com/netblue30/firejail/releases/download/${FIREJAIL_VERSION}"
    deb="firejail_${FIREJAIL_VERSION}_1_amd64.deb"

    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    # apt reads the .deb as the _apt user and cannot traverse mktemp -d's 0700.
    chmod 755 "$tmp"

    # firejail lands setuid root, so a swapped .deb is a permanent local root
    # hole. The clearsigned SHA256 manifest checked against the pinned key is
    # the only step here proving provenance, not just transport integrity.
    curl_fetch "${base}/firejail-${FIREJAIL_VERSION}.asc" "${tmp}/manifest.asc"
    verify_pgp_clearsigned "${tmp}/manifest.asc" \
      "$(dirname "${BASH_SOURCE[0]}")/../lib/keys/firejail.asc" \
      F951164995F5C4006A73411E2CCB36ADFC5849A7 "${tmp}/manifest"

    curl_fetch "${base}/${deb}" "${tmp}/${deb}"
    verify_sha256 "${tmp}/${deb}" "${tmp}/manifest" "$deb"

    chmod 644 "${tmp}/${deb}"
    sudo apt-get install -y "${tmp}/${deb}"
  )
fi

# Rewrite only on drift, so an already-current run never stops for a sudo password.
(
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT
  cat >"$tmp" <<'WRAP'
#!/bin/bash
GTK_IM_MODULE=xim firejail --profile=/etc/firejail/google-chrome.profile --private /usr/bin/google-chrome "$@"
WRAP
  if ! cmp -s "$tmp" /usr/local/bin/chrome || ! [ -x /usr/local/bin/chrome ]; then
    sudo install -m 755 "$tmp" /usr/local/bin/chrome
  fi
)

# Deliberately unsandboxed now; test/e2e.sh asserts these wrappers stay gone.
for wrapper in /usr/local/bin/firefox /usr/local/bin/thunderbird /usr/local/bin/brave.bkp; do
  if [ -e "$wrapper" ]; then
    sudo rm -f "$wrapper"
  fi
done
