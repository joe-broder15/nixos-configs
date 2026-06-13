# NixOS Configurations

This repo defines NixOS configurations for homelab machines, built with flakes.

## Layout

- `machines/` — hardware-specific configs (one file per physical/virtual machine).
- `configurations/` — software/service configs, grouped by host.
- `flake.nix` — fuses a machine config with a host's software configs into a `nixosConfiguration`.
- `scripts/` — helper scripts to assist with deployment.

```
.
├── README.md                              # Repo overview, supporting files, services, and workflow docs.
├── flake.nix                              # Defines nixosConfigurations for homelab and thinkpad.
├── flake.lock                             # Pinned input versions for the flake.
├── configurations/
│   ├── homelab/
│   │   ├── configuration.nix              # Main host module: packages, networking, users, and service options.
│   │   ├── homer.nix                      # Homer dashboard config listing links to other services.
│   │   └── proxy.nix                      # nginx reverse proxy and ACME wildcard certificate config.
│   └── thinkpad/
│       └── configuration.nix              # ThinkPad T14 desktop configuration with KDE Plasma.
├── machines/
│   ├── proxmox-vm.nix                     # Generated hardware profile for the Proxmox VM.
│   └── thinkpad-t14.nix                   # Generated hardware profile for the ThinkPad T14.
└── scripts/
    └── pull-and-rebuild.sh                # Pulls latest changes and runs nixos-rebuild switch for a given configuration.
```

## Adding a new host

1. Add a hardware config under `machines/`.
2. Add a software config directory under `configurations/`.
3. Wire both together as a new `nixosConfigurations.<name>` entry in `flake.nix`.
