#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Building Docker test image..."
docker build -t dotfiles-e2e -f test/Dockerfile .

echo ""
echo "==> Running install.sh + e2e tests..."
docker run --rm dotfiles-e2e
