#!/usr/bin/env bash
set -euo pipefail

# Pull latest changes from this repository and rebuild from the local flake.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLAKE_TARGET="${REPO_ROOT}#homelab"

if [[ ! -d "${REPO_ROOT}/.git" ]]; then
  echo "Expected a git repository at ${REPO_ROOT}" >&2
  exit 1
fi

echo "Using repository at ${REPO_ROOT}"
git -C "${REPO_ROOT}" pull --ff-only

echo "Rebuilding system configuration from flake target ${FLAKE_TARGET}"
sudo nixos-rebuild switch --flake "${FLAKE_TARGET}"

echo "Rebuild complete"
