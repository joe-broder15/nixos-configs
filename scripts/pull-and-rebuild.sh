#!/usr/bin/env bash
set -euo pipefail

# Pull latest changes from this repository, sync to /etc/nixos, rebuild.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_ROOT="/etc/nixos"
FLAKE_TARGET="${TARGET_ROOT}#nixos"

if [[ ! -d "${REPO_ROOT}/.git" ]]; then
  echo "Expected a git repository at ${REPO_ROOT}" >&2
  exit 1
fi

echo "Using repository at ${REPO_ROOT}"
sudo git -C "${REPO_ROOT}" pull --ff-only

echo "Syncing repository files to ${TARGET_ROOT}"
"${REPO_ROOT}/scripts/link-configuration.sh"

echo "Rebuilding system configuration from flake target ${FLAKE_TARGET}"
sudo nixos-rebuild switch --flake "${FLAKE_TARGET}"

echo "Rebuild complete"
