#!/usr/bin/env bash
set -euo pipefail

# This repository is intended to live at /etc/nixos.
REPO_ROOT="/etc/nixos"
FLAKE_TARGET="${REPO_ROOT}#nixos"

if [[ ! -d "${REPO_ROOT}/.git" ]]; then
  echo "Expected a git repository at ${REPO_ROOT}" >&2
  exit 1
fi

echo "Using repository at ${REPO_ROOT}"
sudo git -C "${REPO_ROOT}" pull --ff-only

echo "Rebuilding system configuration from flake target ${FLAKE_TARGET}"
sudo nixos-rebuild switch --flake "${FLAKE_TARGET}"

echo "Rebuild complete"
