# NixOS Configurations

This repo defines NixOS configurations for homelab machines, built with flakes.

## Layout

- `configurations/` — software/service configs, grouped by host.
- `home/` — standalone Home Manager configs, one file per user.
- `flake.nix` — fuses `/etc/nixos/hardware-configuration.nix` (read from the host) with a host's software configs into a `nixosConfiguration`, and exposes Home Manager configs as `homeConfigurations`.
- `scripts/` — helper scripts to assist with deployment.

```
.
├── .sops.yaml                             # SOPS creation rules and public Age recipients for encrypted files under secrets/.
├── README.md                              # Repo overview, supporting files, services, and workflow docs.
├── flake.nix                              # Defines NixOS/Home Manager outputs and imports sops-nix; hardware config read from /etc/nixos/hardware-configuration.nix on the host.
├── flake.lock                             # Pinned input versions for the flake.
├── configurations/
│   ├── homelab/
│   │   ├── configuration.nix              # Main host module: packages, networking, users, and service options (incl. Ollama + Open WebUI).
│   │   ├── domain.nix                     # Defines the shared baseDomain module arg used by proxy.nix and homer.nix.
│   │   ├── homer.nix                      # Homer dashboard config listing links to other services.
│   │   └── proxy.nix                      # nginx reverse proxy and ACME wildcard certificate config.
│   └── thinkpad/
│       ├── configuration.nix              # ThinkPad T14 desktop config with GNOME/GDM, SOPS-managed CIFS credentials, and an automatically generated Ed25519 host key.
│       └── hosts.nix                      # Static hosts-file entries for synology.local, proxmox.local, and homelab.local.
├── home/
│   ├── alias.nix                          # Shell aliases (ll, gs, help, update-sops-keys, hmr, hmp, home, syno) imported by zircon.nix.
│   ├── gtk.nix                            # GTK theme (Dracula), icon theme (Papirus-Dark), and cursor theme (capitaine-cursors) config, imported by zircon.nix.
│   ├── shell.nix                          # Shared zsh/bash/starship configuration imported by zircon.nix.
│   └── zircon.nix                         # Home Manager module for the zircon user (shared by standalone + thinkpad); imports shell.nix, gtk.nix, and alias.nix.
├── secrets/
│   └── common.yaml                        # SOPS-encrypted shared secrets, currently containing the ThinkPad's Synology CIFS credentials.
└── scripts/
    ├── pull-and-rebuild.sh                # Pulls latest changes and runs nixos-rebuild switch for a given configuration.
    ├── pull-and-rebuild-home.sh           # Pulls latest changes and runs home-manager switch for a given home configuration.
    ├── rebuild.sh                         # Runs nixos-rebuild switch for a given configuration, no git pull.
    └── rebuild-home.sh                    # Runs home-manager switch for a given home configuration, no git pull.
```

## Agents

- **autodoc** (`.claude/agents/autodoc.md`) — Keeps README.md, CLAUDE.md, and the curated alias help listing factually accurate after code changes. Updates file listings, path references, one-line descriptions, and alias entries when files or aliases are added, removed, renamed, or repurposed. Does not restructure or redesign documentation — layout and prose decisions are left to humans. Invoke it after staging or committing changes that affect the file tree, aliases, or a module's purpose.

## Adding a new host

1. Add a software config directory under `configurations/`.
2. Wire it together with `/etc/nixos/hardware-configuration.nix` as a new `nixosConfigurations.<name>` entry in `flake.nix`.

## Home Manager

The `zircon` user's Home Manager config lives in `home/zircon.nix` and is consumed two ways:

- **Standalone** (any machine with Nix, including non-NixOS) via the `homeConfigurations."zircon"` flake output:
  `home-manager switch --flake .#zircon` (or `nix run home-manager/master -- switch --flake .#zircon`).
- **NixOS-integrated**: the `thinkpad` config imports `home-manager.nixosModules.home-manager` and sets
  `home-manager.users.zircon = import ./home/zircon.nix;`, so the profile is built and activated with every `nixos-rebuild`.

The same module file is reused in both paths; `home.username`/`home.homeDirectory` are set explicitly so it works standalone, and the NixOS module sets the same values via `mkDefault` so there is no conflict.
