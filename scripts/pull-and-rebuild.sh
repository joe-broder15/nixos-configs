#!/usr/bin/env bash
set -euo pipefail

# Pull latest changes from this repository and rebuild a selected local flake closure.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <nixosConfiguration-name>" >&2
  echo "Example: $0 homelab" >&2
  exit 1
fi

CLOSURE_NAME="$1"

if [[ ! "${CLOSURE_NAME}" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Invalid closure name: ${CLOSURE_NAME}" >&2
  echo "Allowed characters: letters, numbers, dot, underscore, dash." >&2
  exit 1
fi

FLAKE_TARGET="${REPO_ROOT}#${CLOSURE_NAME}"

if [[ ! -d "${REPO_ROOT}/.git" ]]; then
  echo "Expected a git repository at ${REPO_ROOT}" >&2
  exit 1
fi

if [[ ! -w "${REPO_ROOT}/.git" ]]; then
  echo "Repository metadata is not writable: ${REPO_ROOT}/.git" >&2
  echo "Fix ownership, then rerun:" >&2
  echo "  sudo chown -R \"$(id -un):$(id -gn)\" \"${REPO_ROOT}\"" >&2
  exit 1
fi

echo "Using repository at ${REPO_ROOT}"
git -C "${REPO_ROOT}" pull --ff-only

if ! nix eval "${REPO_ROOT}#nixosConfigurations.${CLOSURE_NAME}.config.system.build.toplevel.drvPath" >/dev/null 2>&1; then
  echo "Unknown nixosConfiguration closure: ${CLOSURE_NAME}" >&2
  echo "Available closures:" >&2
  nix eval --raw --apply 'x: builtins.concatStringsSep " " (builtins.attrNames x)' "${REPO_ROOT}#nixosConfigurations" 2>/dev/null >&2 || true
  echo >&2
  exit 1
fi

echo "Rebuilding system configuration from flake target ${FLAKE_TARGET}"
sudo nixos-rebuild switch --flake "${FLAKE_TARGET}"

echo "Rebuild complete"
