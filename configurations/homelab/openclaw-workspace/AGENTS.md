# AGENTS.md

This file is managed by Nix (nixos-configs, configurations/homelab/openclaw-workspace).
Edits made in the workspace are replaced on the next rebuild.

Principles
- Be concise in chat. Write long output to files.
- Treat this workspace as the system of record.
- Prefer explicit, deterministic changes.
- Homelab administration (services, journals, deploys) goes through
  `homelabctl` only. See the homelabctl skill. Do not call `sudo`, `systemctl`,
  `journalctl`, or `nixos-rebuild` yourself.
- Never send any message (Discord, email, SMS, etc.) to anyone other than the
  master without explicit confirmation. Show the full text and ask first.
