#!/usr/bin/env bash
set -e

NEEDS_BUILD="0"
if ! command -v firejail &>/dev/null; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$(firejail --version | head -1 | grep -oP '[\d.]+')
  if [ "${CURRENT_VERSION}" != "${FIREJAIL_VERSION}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    DEB=$(mktemp --suffix=.deb)
    trap 'rm -f "$DEB"' EXIT
    wget -q "https://github.com/netblue30/firejail/releases/download/${FIREJAIL_VERSION}/firejail_${FIREJAIL_VERSION}_1_amd64.deb" -O "$DEB"
    chmod 644 "$DEB"
    sudo apt-get install -y "$DEB"
  )
fi

# Remove stale firefox/thunderbird wrappers (no longer sandboxed)
sudo rm -f /usr/local/bin/{firefox,thunderbird}

# Install/update wrapper scripts
sudo tee /usr/local/bin/chrome > /dev/null <<WRAP
#!/bin/bash
GTK_IM_MODULE=xim firejail --profile=/etc/firejail/google-chrome.profile --private /usr/bin/google-chrome "\$@"
WRAP

sudo chmod +x /usr/local/bin/chrome

# Remove stale wrappers
sudo rm -f /usr/local/bin/brave.bkp /usr/local/bin/dropdox /usr/local/bin/1password.bkp /usr/local/bin/firefox.bkp /usr/local/bin/thunderbird.bkp
