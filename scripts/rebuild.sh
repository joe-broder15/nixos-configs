#!/usr/bin/env bash
set -euo pipefail

# Rebuild a selected local flake closure using the working tree as-is (no git pull).
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <nixosConfiguration-name>" >&2
  echo "Example: $0 homelab" >&2
  exit 1
fi

CLOSURE_NAME="$1"

sudo nixos-rebuild switch --impure --flake "${REPO_ROOT}#${CLOSURE_NAME}"
