#!/usr/bin/env bash
set -euo pipefail

# This repository is intended to live at /etc/nixos.
EXPECTED_ROOT="/etc/nixos"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${EXPECTED_ROOT}/configuration.nix"

if [[ "${REPO_ROOT}" != "${EXPECTED_ROOT}" ]]; then
  echo "Repository root is ${REPO_ROOT}" >&2
  echo "This repo is expected to be cloned to ${EXPECTED_ROOT}" >&2
  exit 1
fi

if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "Missing ${CONFIG_FILE}" >&2
  exit 1
fi

echo "Repository layout check passed at ${EXPECTED_ROOT}"
echo "configuration.nix is present at ${CONFIG_FILE}"
