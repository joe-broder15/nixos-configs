# TOOLS.md

This file is managed by Nix. A plugin report is appended below.

`homelabctl` is the only allowed interface for host administration. Use the
homelabctl skill for commands, denylist, and JSON output. Do not call `sudo`,
`systemctl`, `journalctl`, or `nixos-rebuild` directly.
