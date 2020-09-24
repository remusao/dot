#!/usr/bin/env sh

set -e

NEEDS_BUILD="0"
if ! [ -f "/home/remi/.local/bin/terraform" ]; then
  NEEDS_BUILD="1"
else
  CURRENT_VERSION=$(terraform --version | head -n 1)
  if [ "${CURRENT_VERSION}" != "Terraform v${TERRAFORM}" ]; then
    NEEDS_BUILD="1"
  fi
fi

if [ "${NEEDS_BUILD}" = "1" ]; then
  curl -L "https://releases.hashicorp.com/terraform/${TERRAFORM}/terraform_${TERRAFORM}_linux_amd64.zip" -o terraform.zip
  unzip terraform.zip
  mv terraform ~/.local/bin/terraform
  rm -frv terraform.zip
  chmod 755 ~/.local/bin/terraform
fi
