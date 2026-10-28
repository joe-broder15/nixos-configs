# TOOLS.md

This file is managed by Nix. A plugin report is appended below.

`homelabctl` is the only allowed interface for host administration. Use the
homelabctl skill for commands, denylist, and JSON output. Do not call `sudo`,
`systemctl`, `journalctl`, or `nixos-rebuild` directly.

`mcp-nixos` is a stdio MCP server for public NixOS, nixpkgs, and Home Manager
lookups. It is registered on the gateway under `mcp.servers`, separate from
the Codex plugin's `codex_apps` server. It is not an admin interface.
