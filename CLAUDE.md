# NixOS Configurations

This repo defines NixOS configurations for homelab machines, built with flakes.

## Layout

- `machines/` — hardware-specific configs (one file per physical/virtual machine).
- `configurations/` — software/service configs, grouped by host.
- `home/` — standalone Home Manager configs, one file per user.
- `flake.nix` — fuses a machine config with a host's software configs into a `nixosConfiguration`, and exposes Home Manager configs as `homeConfigurations`.
- `scripts/` — helper scripts to assist with deployment.

```
.
├── README.md                              # Repo overview, supporting files, services, and workflow docs.
├── flake.nix                              # Defines nixosConfigurations (homelab, thinkpad) and homeConfigurations (zircon).
├── flake.lock                             # Pinned input versions for the flake.
├── configurations/
│   ├── homelab/
│   │   ├── configuration.nix              # Main host module: packages, networking, users, and service options.
│   │   ├── homer.nix                      # Homer dashboard config listing links to other services.
│   │   └── proxy.nix                      # nginx reverse proxy and ACME wildcard certificate config.
│   └── thinkpad/
│       └── configuration.nix              # ThinkPad T14 desktop configuration with KDE Plasma.
├── home/
│   └── zircon.nix                         # Home Manager module for the zircon user (shared by standalone + thinkpad).
├── machines/
│   ├── proxmox-vm.nix                     # Generated hardware profile for the Proxmox VM.
│   └── thinkpad-t14.nix                   # Generated hardware profile for the ThinkPad T14.
└── scripts/
    ├── pull-and-rebuild.sh                # Pulls latest changes and runs nixos-rebuild switch for a given configuration.
    └── pull-and-rebuild-home.sh           # Pulls latest changes and runs home-manager switch for a given home configuration.
```

## Adding a new host

1. Add a hardware config under `machines/`.
2. Add a software config directory under `configurations/`.
3. Wire both together as a new `nixosConfigurations.<name>` entry in `flake.nix`.

## Home Manager

The `zircon` user's Home Manager config lives in `home/zircon.nix` and is consumed two ways:

- **Standalone** (any machine with Nix, including non-NixOS) via the `homeConfigurations."zircon"` flake output:
  `home-manager switch --flake .#zircon` (or `nix run home-manager/master -- switch --flake .#zircon`).
- **NixOS-integrated**: the `thinkpad` config imports `home-manager.nixosModules.home-manager` and sets
  `home-manager.users.zircon = import ./home/zircon.nix;`, so the profile is built and activated with every `nixos-rebuild`.

The same module file is reused in both paths; `home.username`/`home.homeDirectory` are set explicitly so it works standalone, and the NixOS module sets the same values via `mkDefault` so there is no conflict.
