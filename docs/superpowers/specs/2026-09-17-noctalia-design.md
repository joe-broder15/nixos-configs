# Noctalia setup for zircon (thinkpad + desktop)

## Context

`thinkpad` and `desktop` currently run GNOME/GDM as their only desktop
session, wired up via `services.desktopManager.gnome.enable` in each
host's `configuration.nix`. The user wants Noctalia — a Wayland
bar/shell/launcher system (v5+, compositor-agnostic) — added for the
`zircon` Home Manager profile on both machines.

Noctalia is not a compositor itself and does not run on GNOME/Mutter.
It requires a separate Wayland compositor; Hyprland was chosen as that
compositor. GNOME stays installed as a fallback session so this is
reversible with no risk to the existing desktop setup.

## Decisions

- **Hosts**: both `thinkpad` and `desktop`.
- **Management**: entirely through Home Manager (`programs.noctalia`
  from Noctalia's `homeModules.default`), not the NixOS module
  (`nixosModules.default`) — the user does not want
  `recommendedServices`/systemd wiring done via the NixOS module route.
- **Compositor**: Hyprland, enabled at the system level
  (`programs.hyprland.enable`). GDM keeps offering both the GNOME and
  Hyprland sessions at login; no existing GNOME config changes.
- **Theme**: `settings.theme.mode = "dark"` only. No builtin palette
  override (left at Noctalia's default) and no wallpaper configuration
  — the user will handle those later via Noctalia's own UI/config if
  desired.
- **Hyprland dotfiles**: explicitly out of scope. No
  `wayland.windowManager.hyprland` Home Manager config, no custom
  keybindings/monitor layout. Hyprland auto-generates a default
  `~/.config/hypr/hyprland.conf` with usable default keybindings on
  first login if none exists; that's relied on for now.
- **Duplication**: `thinkpad/configuration.nix` and
  `desktop/configuration.nix` already duplicate their GNOME/services
  block rather than sharing a "desktop-common" module. The new
  Hyprland/service/cache additions follow that same existing pattern
  rather than introducing a new shared abstraction — out of scope for
  this change.

## Design

### 1. Flake wiring (`flake.nix`)

- Add a `noctalia` flake input:
  ```nix
  noctalia = {
    url = "github:noctalia-dev/noctalia";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  ```
- Capture `noctalia` in the `outputs` function arguments.
- On the `thinkpad` and `desktop` `nixosConfigurations` only, pass it
  to Home Manager and extend the `zircon` user's module list:
  ```nix
  home-manager.extraSpecialArgs = { inherit noctalia; };
  home-manager.users.zircon = {
    imports = [
      ./home/zircon.nix
      ./home/noctalia.nix
    ];
  };
  ```
- `homeConfigurations.zircon` (the standalone output) is left
  unchanged — it keeps importing only `./home/zircon.nix`, so
  standalone/non-NixOS Home Manager use is unaffected.

### 2. Host changes

Applied identically to `configurations/thinkpad/configuration.nix`
and `configurations/desktop/configuration.nix`:

- `programs.hyprland.enable = true;`
- `services.power-profiles-daemon.enable = true;`
- `services.upower.enable = true;`
- Noctalia binary cache substituter:
  ```nix
  nix.settings = {
    extra-substituters = [ "https://noctalia.cachix.org" ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };
  ```

NetworkManager and Bluetooth are already enabled (`base.nix`,
`common/logitech.nix`), so nothing additional is needed for those.

### 3. Home Manager module (new `home/noctalia.nix`)

```nix
{ noctalia, ... }:

{
  imports = [ noctalia.homeModules.default ];

  programs.noctalia = {
    enable = true;
    systemd.enable = true;
    settings.theme.mode = "dark";
  };
}
```

This file is only imported for the `thinkpad`/`desktop` NixOS-integrated
Home Manager users (via `flake.nix`, see above), not from
`home/zircon.nix` itself.

### 4. Explicitly out of scope

- No GNOME removal or GDM reconfiguration beyond Hyprland becoming an
  additional selectable session.
- No custom Hyprland config, keybindings, or monitor layout.
- No wallpaper or non-default theme palette configuration.

## Testing plan

1. `nixos-rebuild switch --flake .#thinkpad` (and separately for
   `desktop`), via the existing `scripts/rebuild.sh` helper.
2. Confirm the build succeeds and the Noctalia package fetches from
   its binary cache rather than building from source.
3. Log out of the GNOME session; confirm GDM lists a Hyprland session
   option and that it starts.
4. In the Hyprland session, confirm the Noctalia bar/launcher/dock
   appear (via the `systemd.enable` user service) and that basic
   Noctalia UI (launcher, control center) is reachable.
5. Confirm GNOME still starts normally afterward (no regression to
   the existing session).
