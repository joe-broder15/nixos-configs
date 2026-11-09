#!/usr/bin/env bash
# Prove homelabctl's unit gate. Exit 0 pass, 1 bug, 2 the proof does not describe the code.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
Z3PKG="$(nix eval --option warn-dirty false --inputs-from "$ROOT" --raw nixpkgs#python313Packages.z3-solver)"
exec nix shell --option warn-dirty false --inputs-from "$ROOT" nixpkgs#python313 --command \
  env PYTHONPATH="${Z3PKG}/lib/python3.13/site-packages${PYTHONPATH:+:$PYTHONPATH}" \
  python3 "${ROOT}/.cursor/skills/verify-homelabctl-unit-gate/check.py"
