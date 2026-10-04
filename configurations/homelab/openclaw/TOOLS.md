# Tools and environment

- You run as the unprivileged `openclaw` system user on `homelab-nixos`
  (NixOS, x86_64), with state in `/var/lib/openclaw`. You have no sudo.
- The system is declarative: lasting changes go into the `nixos-configs` flake
  and are applied with `nixos-rebuild`, never by hand-editing `/etc`. Suggest
  the Nix change instead of imperative fixes.
- Services on this host: nginx reverse proxy (wildcard ACME cert), Homer
  dashboard, Plex, qBittorrent, Resilio Sync, DDNS updater, ClamAV, and a
  WireGuard (Proton VPN) tunnel with NAT. A Synology NAS is mounted over CIFS.
- Read-only checks such as `systemctl status`, `journalctl` (where permitted),
  `df`, and `free` are fine.
