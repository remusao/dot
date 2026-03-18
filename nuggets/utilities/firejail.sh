#!/usr/bin/env bash
set -e

NEEDS_BUILD="0"
if ! command -v firejail &>/dev/null; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$(firejail --version | head -1 | grep -oP '[\d.]+')
  if [ "${CURRENT_VERSION}" != "${FIREJAIL}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  (
    DEB=$(mktemp --suffix=.deb)
    trap 'rm -f "$DEB"' EXIT
    wget -q "https://github.com/netblue30/firejail/releases/download/${FIREJAIL}/firejail_${FIREJAIL}_1_amd64.deb" -O "$DEB"
    chmod 644 "$DEB"
    sudo apt-get install -y "$DEB"
  )
fi

# Create sandbox directories
mkdir -p ~/.sandboxes/{firefox,thunderbird}

# Install/update wrapper scripts
sudo tee /usr/local/bin/firefox > /dev/null <<WRAP
#!/bin/bash
firejail --profile=/etc/firejail/firefox.profile --private=${HOME}/.sandboxes/firefox/ /usr/bin/firefox --no-remote "\$@"
WRAP

sudo tee /usr/local/bin/thunderbird > /dev/null <<WRAP
#!/bin/bash
GTK_IM_MODULE=xim firejail --profile=/etc/firejail/thunderbird.profile --private=${HOME}/.sandboxes/thunderbird /usr/bin/thunderbird "\$@"
WRAP

sudo tee /usr/local/bin/chrome > /dev/null <<WRAP
#!/bin/bash
GTK_IM_MODULE=xim firejail --profile=/etc/firejail/google-chrome.profile --private /usr/bin/google-chrome "\$@"
WRAP

sudo chmod +x /usr/local/bin/{firefox,thunderbird,chrome}

# Remove stale wrappers
sudo rm -f /usr/local/bin/brave.bkp /usr/local/bin/dropdox /usr/local/bin/1password.bkp
