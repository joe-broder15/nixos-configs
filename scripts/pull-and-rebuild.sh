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

git -C "${REPO_ROOT}" pull --ff-only

sudo nixos-rebuild switch --flake "${REPO_ROOT}#${CLOSURE_NAME}"
