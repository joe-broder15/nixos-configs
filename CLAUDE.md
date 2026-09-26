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
│   ├── common/
│   │   ├── base.nix                       # Shared base NixOS settings: NetworkManager, timezone, locale/xkb, flakes enabled, unfree allowed, and the pinned stateVersion; imported by all three hosts (homelab, thinkpad, desktop).
│   │   ├── crypto.nix                     # Shared SOPS/Age setup: generates an Ed25519 SSH host key and sets it as the sops-nix Age identity; also installs age and sops system packages for manually inspecting/editing sops-encrypted files.
│   │   ├── hosts.nix                      # Static hosts-file entries for proxmox.local and homelab.local (synology.local comes from common/synology.nix); imported by thinkpad and desktop.
│   │   ├── logitech.nix                   # Enables hardware.bluetooth and hardware.logitech.wireless plus programs.solaar, so Solaar can manage Logitech peripherals (e.g. MX Master mouse, MX Keys keyboard) via Unifying receiver or Bluetooth; imported by thinkpad and desktop.
│   │   ├── namecheap-ddns-updater.nix      # DDNS Updater package and services.ddns-updater block: { domain }: { ... } takes domain as a parameter, hardcodes provider to "namecheap", and sources only the account password from sops-nix; imported only by homelab.
│   │   ├── resilio.nix                    # Reusable resilio-sync component: web-UI-managed services.resilio, license and WebUI creds sourced from sops-nix, /resilio-shared-folders created via tmpfiles; imported by thinkpad and desktop (homelab keeps its own separate, non-sops resilio config).
│   │   ├── synology.nix                   # Shared CIFS mount for //synology.local/Library1, with credentials rendered by sops-nix.
│   │   └── wireguard.nix                  # Reusable wg0 client component: { secretKey, natExternalInterface ? null }: owns wireguard-tools, its sops-nix secret, and networking.wg-quick config; adds networking.nat only when natExternalInterface is set.
│   ├── desktop/
│   │   └── configuration.nix              # Desktop-class machine config with GNOME/GDM, same profile as ../thinkpad/configuration.nix plus NVIDIA GPU support (RTX 2080 Super via hardware.nvidia, proprietary driver); imports ../common/base.nix, ../common/crypto.nix and ../common/synology.nix for SOPS-managed CIFS credentials, ../common/resilio.nix for Resilio Sync, ../common/hosts.nix, ../common/logitech.nix, and ../common/wireguard.nix (client-only, no NAT; own WireGuard secret, separate from thinkpad's).
│   ├── homelab/
│   │   ├── configuration.nix              # Main host module: packages, networking, users, and service options (incl. Ollama + Open WebUI); imports ../common/base.nix, ../common/crypto.nix and ../common/synology.nix for SOPS-managed CIFS credentials, (import ../common/namecheap-ddns-updater.nix { domain = "ddns.clubtropicalexcellent.vip"; }) for its sops-nix wiring, and ../common/wireguard.nix (with NAT out ens18).
│   │   ├── domain.nix                     # Defines the shared baseDomain module arg used by proxy.nix and homer.nix.
│   │   ├── homer.nix                      # Homer dashboard config listing links to other services.
│   │   └── proxy.nix                      # nginx reverse proxy and ACME wildcard certificate config.
│   └── thinkpad/
│       └── configuration.nix              # ThinkPad T14 desktop config with GNOME/GDM; imports ../common/base.nix, ../common/crypto.nix and ../common/synology.nix for SOPS-managed CIFS credentials, ../common/resilio.nix for Resilio Sync, ../common/hosts.nix, ../common/logitech.nix, and ../common/wireguard.nix (client-only, no NAT).
├── home/
│   ├── alias.nix                          # Shell aliases (ll, gs, help, host-age-pubkey, user-age-pubkey, update-sops-keys, hmr, hmp, home, syno, jfu, wg-start, wg-stop, icat, kdiff, palette, zls, za, zka) imported by zircon.nix.
│   ├── gtk.nix                            # GTK theme (Dracula, via pkgs.dracula-theme, incl. gtk4), icon theme (vanilla Papirus-Dark), and cursor theme (Dracula-cursors, bundled in pkgs.dracula-theme) config, imported by zircon.nix.
│   ├── shell.nix                          # Shared zsh/bash/starship configuration imported by zircon.nix.
│   ├── zellij.nix                         # Zellij config (Dracula theme, full pane frames, no zsh auto-start) with a zellaude tab bar (Claude Code activity per tab; pinned release wasm, jq for its hook) on top and a zjstatus (nixpkgs zellijPlugins) + zjstatus-hints (pinned release wasm) keybinding-hints bar on the bottom; imported by zircon.nix.
│   └── zircon.nix                         # Home Manager module for the zircon user (shared by standalone + thinkpad + desktop); imports shell.nix, gtk.nix, alias.nix, and zellij.nix; configures kitty as the terminal (programs.kitty: font, tab bar, pane-splitting keybindings, command_palette keybinding); bootstraps Spacemacs into ~/.emacs.d on first activation (home.activation.installSpacemacs) alongside the emacs package.
├── secrets/
│   └── common.yaml                        # SOPS-encrypted shared secrets: Synology CIFS credentials (homelab, thinkpad, and desktop), Namecheap API credentials (homelab proxy.nix ACME DNS challenge), per-host WireGuard wg0 configs (homelab, thinkpad, and desktop, common/wireguard.nix), the DDNS Updater Namecheap account password (common/namecheap-ddns-updater.nix, used by homelab; domain and provider are no longer sops-sourced), and Resilio Sync's license/WebUI credentials (common/resilio.nix, used by thinkpad and desktop).
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
- **NixOS-integrated**: the `thinkpad` and `desktop` configs import `home-manager.nixosModules.home-manager` and set
  `home-manager.users.zircon = import ./home/zircon.nix;`, so the profile is built and activated with every `nixos-rebuild`.

The same module file is reused in both paths; `home.username`/`home.homeDirectory` are set explicitly so it works standalone, and the NixOS module sets the same values via `mkDefault` so there is no conflict.

On NixOS-integrated hosts, don't run a standalone `home-manager switch`: it installs a second copy of the packages into `~/.nix-profile`, which the next `nixos-rebuild` uninstalls, breaking already-open shells that resolved binaries (e.g. starship) from there. The `hmr`/`hmp` aliases detect this (via the `home-manager-$USER.service` unit) and delegate to `scripts/rebuild.sh` / `scripts/pull-and-rebuild.sh` instead.
