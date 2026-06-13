#!/usr/bin/env bash
set -euo pipefail

# Pull latest changes from this repository and switch to a selected local Home Manager config.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <homeConfiguration-name>" >&2
  echo "Example: $0 zircon" >&2
  exit 1
fi

CONFIG_NAME="$1"

git -C "${REPO_ROOT}" pull --ff-only

home-manager switch --flake "${REPO_ROOT}#${CONFIG_NAME}"
