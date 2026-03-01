#!/usr/bin/env bash
set -euo pipefail

# Sync tracked NixOS config files from this repository into /etc/nixos.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_ROOT="/etc/nixos"
MODULE_SOURCE_DIR="${REPO_ROOT}/homelab"
MODULE_TARGET_DIR="${TARGET_ROOT}/homelab"

ROOT_FILES=(
  "flake.nix"
  "flake.lock"
)

MODULE_FILES=(
  "configuration.nix"
  "proxy.nix"
  "homer.nix"
)

echo "Syncing flake files from ${REPO_ROOT} to ${TARGET_ROOT}"
sudo install -d -m 0755 "${TARGET_ROOT}"

for file in "${ROOT_FILES[@]}"; do
  if [[ ! -f "${REPO_ROOT}/${file}" ]]; then
    echo "Missing required source file: ${REPO_ROOT}/${file}" >&2
    exit 1
  fi

  sudo install -m 0644 "${REPO_ROOT}/${file}" "${TARGET_ROOT}/${file}"
done

echo "Syncing module files from ${MODULE_SOURCE_DIR} to ${MODULE_TARGET_DIR}"
sudo install -d -m 0755 "${MODULE_TARGET_DIR}"

for file in "${MODULE_FILES[@]}"; do
  if [[ ! -f "${MODULE_SOURCE_DIR}/${file}" ]]; then
    echo "Missing required source file: ${MODULE_SOURCE_DIR}/${file}" >&2
    exit 1
  fi

  sudo install -m 0644 "${MODULE_SOURCE_DIR}/${file}" "${MODULE_TARGET_DIR}/${file}"
done

if [[ ! -f "${TARGET_ROOT}/hardware-configuration.nix" ]]; then
  echo "Missing required host file: ${TARGET_ROOT}/hardware-configuration.nix" >&2
  echo "Generate it with: sudo nixos-generate-config" >&2
  exit 1
fi

echo "Sync complete."
