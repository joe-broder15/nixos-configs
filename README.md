# nixos-configs

NixOS configurations for homelab machines, built with flakes.

## Configurations

### homelab
Opinionated NixOS configuration for the homelab server running on a Proxmox VM.
- `configurations/homelab/configuration.nix` is the main module for host/system settings; it also imports the shared `configurations/common/base.nix` module for common host defaults, `configurations/common/crypto.nix` and `configurations/common/synology.nix` modules for a CIFS mount at `//synology.local/Library1` with credentials rendered by sops-nix, along with `configurations/common/namecheap-ddns-updater.nix` (imported as `(import ../common/namecheap-ddns-updater.nix { domain = "ddns.clubtropicalexcellent.vip"; })`) for its sops-nix wiring and the shared `configurations/common/wireguard.nix` module (parameterized with its own secret key and NAT'd out `ens18`).
- `configurations/homelab/proxy.nix` contains nginx reverse-proxy and ACME certificate settings.
- `configurations/common/namecheap-ddns-updater.nix` is a `{ domain }: { ... }` function containing the DDNS Updater package, its sops-nix secrets/template, and the `services.ddns-updater` block; it hardcodes `provider = "namecheap"`, takes `domain` as a parameter, and sources only the account password from sops-nix. It lives under `configurations/common/` but is only imported by homelab.
- Hardware configuration is read from `/etc/nixos/hardware-configuration.nix` on the host (not versioned in this repo).

### thinkpad
NixOS configuration for ThinkPad T14 laptop with GNOME desktop.
- `configurations/thinkpad/configuration.nix` contains the desktop configuration; it imports the shared `configurations/common/base.nix` module for common host defaults, `configurations/common/crypto.nix` and `configurations/common/synology.nix` modules for a CIFS mount at `//synology.local/Library1` with credentials rendered by sops-nix, the shared `configurations/common/resilio.nix` module for Resilio Sync, `configurations/common/hosts.nix` for static host entries, `configurations/common/logitech.nix` for Solaar/Logitech peripheral support, plus the shared `configurations/common/wireguard.nix` module (client-only, no NAT since thinkpad doesn't route other traffic through the tunnel).
- `configurations/common/hosts.nix` adds static `networking.hosts` entries for `proxmox.local` and `homelab.local` (the `synology.local` entry is added by `configurations/common/synology.nix`). It is imported by both thinkpad and desktop.
- `configurations/common/resilio.nix` is a web-UI-managed Resilio Sync component: it installs `pkgs.resilio-sync`, sources the license and WebUI credentials from sops-nix (the license is materialized as a `.btskey` file and applied via `ExecStartPre`), and creates `/resilio-shared-folders`. It lives under `configurations/common/` and is imported by thinkpad and desktop; homelab keeps its own separate, non-sops-sourced Resilio Sync config.
- `configurations/common/logitech.nix` enables `hardware.bluetooth`, `hardware.logitech.wireless`, and `programs.solaar` so Solaar can manage Logitech peripherals (e.g. MX Master mouse, MX Keys keyboard) via Unifying receiver or Bluetooth. It is imported by both thinkpad and desktop.
- Hardware configuration is read from `/etc/nixos/hardware-configuration.nix` on the host (not versioned in this repo).

### desktop
NixOS configuration for a desktop-class machine with GNOME desktop, using the same profile as thinkpad.
- `configurations/desktop/configuration.nix` contains the desktop configuration; it imports the same shared modules as thinkpad — `configurations/common/base.nix`, `configurations/common/crypto.nix` and `configurations/common/synology.nix` for the CIFS mount, `configurations/common/resilio.nix` for Resilio Sync, `configurations/common/hosts.nix`, and `configurations/common/logitech.nix` — plus its own `configurations/common/wireguard.nix` instance (client-only, no NAT, using a WireGuard secret separate from thinkpad's).
- Hardware configuration is read from `/etc/nixos/hardware-configuration.nix` on the host (not versioned in this repo).

The `flake.nix` (repo root) exposes all three configurations as `nixosConfigurations.homelab`, `nixosConfigurations.thinkpad`, and `nixosConfigurations.desktop` for flake-based rebuilds.

## Home Manager

The `zircon` user's Home Manager configuration is tracked in this repo at `home/zircon.nix` and exposed from the root `flake.nix` as `homeConfigurations.zircon`.

It can be used in two ways:

- **Standalone** — on any machine with Nix installed (it does *not* have to be NixOS). A non-NixOS user can apply it directly from this repo:

  ```sh
  # First time, without home-manager installed:
  nix run home-manager/master -- switch --flake /path/to/nixos-configs#zircon

  # Once home-manager is on PATH:
  home-manager switch --flake /path/to/nixos-configs#zircon
  ```

- **NixOS-integrated (thinkpad, desktop)** — the `thinkpad` and `desktop` configurations import the Home Manager NixOS module and activate the `zircon` profile automatically on every `nixos-rebuild switch`, so no separate `home-manager` command is needed there.

Both paths share the same `home/zircon.nix` module, so changes apply consistently regardless of how it is built.

## Supporting files that must exist on the host

### homelab configuration
- `/etc/nixos/hardware-configuration.nix` – generated by `nixos-generate-config`. The repo expects this file to be present on the system and does not version it.

The WireGuard `wg0` config and the DDNS Updater config are no longer plain files on the host; both are rendered at activation time by sops-nix (see below) — `networking.wg-quick.interfaces.wg0.configFile` points at `sops.secrets."wireguard_secrets/homelab_proton_vpn_config".path`, and `services.ddns-updater.environment.CONFIG_FILEPATH` points at `sops.templates."ddns-updater-config".path`.

### thinkpad configuration
- `/etc/nixos/hardware-configuration.nix` – generated by `nixos-generate-config`. The repo expects this file to be present on the system and does not version it.

### desktop configuration
- `/etc/nixos/hardware-configuration.nix` – generated by `nixos-generate-config`. The repo expects this file to be present on the system and does not version it.

Create or copy these files on the machine before rebuilding.

The Synology CIFS credentials (shared by homelab, thinkpad, and desktop via `configurations/common/synology.nix`), the Namecheap API credentials (used by `configurations/homelab/proxy.nix` for ACME DNS challenges), the per-host WireGuard `wg0` configs (used by the shared `configurations/common/wireguard.nix` module, imported separately by homelab, thinkpad, and desktop), the DDNS Updater Namecheap account password (used by `configurations/common/namecheap-ddns-updater.nix`, imported only by homelab; domain and provider are no longer sops-sourced), and Resilio Sync's license and WebUI credentials (used by `configurations/common/resilio.nix`, imported by thinkpad and desktop) are stored encrypted in `secrets/common.yaml` and rendered at activation time by sops-nix using `/etc/ssh/ssh_host_ed25519_key` as an Age identity (set up by `configurations/common/crypto.nix`). The host key is generated automatically when absent.

## Services configured here

- NetworkManager for interface management.
- WireGuard server with NAT for clients.
- OpenSSH for remote access.
- nginx reverse proxy for service subdomains.
- ACME/Let's Encrypt wildcard certificates (Namecheap DNS challenge).
- Homer dashboard with links to other services.
- DDNS Updater service and web UI.
- qbittorrent headless client.
- Plex Media Server.
- Resilio Sync with WebUI and shared-folder root at `/resilio-shared-folders`.
- ClamAV daemon and on-demand scanner.
- Ollama local LLM server (CPU-only, `pkgs.ollama-cpu`), listening on `0.0.0.0` with `deepseek-r1:1.5b` preloaded.
- Open WebUI as a front-end for Ollama.
- CIFS mount for `//synology.local/Library1`.
- Miscellaneous CLI tooling: `vim`, `wget`, `htop`, `fastfetch`, `tree`, `wireguard-tools`, etc.

## Service URLs

- Homer: `https://homer.local.clubtropicalexcellent.vip`
- Plex: `https://plex.local.clubtropicalexcellent.vip`
- qBittorrent: `https://qbittorrent.local.clubtropicalexcellent.vip`
- Resilio Sync: `https://resilio.local.clubtropicalexcellent.vip`
- DDNS Updater: `https://ddns.local.clubtropicalexcellent.vip`
- Open WebUI: `https://openwebui.local.clubtropicalexcellent.vip`
- Proxmox: `https://proxmox.local.clubtropicalexcellent.vip`

## Resilio notes

- Resilio WebUI listens on `127.0.0.1:9999` and is exposed through nginx.
- The shared folder root is `/resilio-shared-folders`.
- The directory is created declaratively via `systemd.tmpfiles` with ownership `rslsync:rslsync`.

## Scripts

Four helper scripts live in `scripts/`:

- `scripts/pull-and-rebuild.sh <closure>` – runs `git -C <repo-root> pull --ff-only` (where `<repo-root>` is resolved from the script location), then runs `sudo nixos-rebuild switch --impure --flake <repo-root>#<closure>`.
- `scripts/pull-and-rebuild-home.sh <name>` – runs `git -C <repo-root> pull --ff-only` (where `<repo-root>` is resolved from the script location), then runs `home-manager switch --flake <repo-root>#<name>` for a `homeConfigurations` entry (e.g. `zircon`). No `sudo`, since Home Manager activates as the invoking user.
- `scripts/rebuild.sh <closure>` – same as `pull-and-rebuild.sh` but skips the `git pull`, rebuilding from the working tree as-is.
- `scripts/rebuild-home.sh <name>` – same as `pull-and-rebuild-home.sh` but skips the `git pull`, switching from the working tree as-is.

Ensure scripts are executable (`chmod +x scripts/*.sh`). They assume the repository is cloned on the target machine and that `sudo` is configured.

## Rebuild commands

- homelab: `sudo nixos-rebuild switch --flake /path/to/nixos-configs#homelab`
- thinkpad: `sudo nixos-rebuild switch --flake /path/to/nixos-configs#thinkpad`
- desktop: `sudo nixos-rebuild switch --flake /path/to/nixos-configs#desktop`

## Typical workflow

1. Clone the repository onto the host.
2. Edit or update the configuration as needed.
3. Execute `./scripts/pull-and-rebuild.sh <configuration>` to fetch the latest changes and rebuild the system from the local flake (where `<configuration>` is `homelab`, `thinkpad`, or `desktop`).

For homelab, after each rebuild, verify that services (nginx, ACME issuance, DDNS updater, Resilio Sync, Plex, qbittorrent, WireGuard, Ollama, Open WebUI, CIFS mount) are healthy.
