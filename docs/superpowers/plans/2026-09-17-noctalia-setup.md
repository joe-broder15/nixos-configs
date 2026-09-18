# Noctalia Setup (thinkpad + desktop) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Noctalia (a Wayland bar/shell/launcher) for the `zircon` user on `thinkpad` and `desktop`, backed by Hyprland, entirely via Home Manager, with GNOME kept as a GDM fallback session.

**Architecture:** A new flake input (`noctalia`) is threaded into Home Manager via `extraSpecialArgs` for the `thinkpad` and `desktop` `nixosConfigurations` only. A new `home/noctalia.nix` Home Manager module imports Noctalia's `homeModules.default` and enables it with dark-mode-only theme settings. Each host's `configuration.nix` gains `programs.hyprland.enable` plus Noctalia's recommended services and binary cache, duplicated across both host files (matching this repo's existing thinkpad/desktop duplication pattern — no new shared module).

**Tech Stack:** Nix flakes, NixOS modules, Home Manager, Hyprland, Noctalia (`github:noctalia-dev/noctalia`).

**Spec:** `docs/superpowers/specs/2026-09-17-noctalia-design.md`

## Global Constraints

- Both `thinkpad` and `desktop` get this change; no other host is touched.
- Noctalia is managed only through Home Manager (`programs.noctalia` / `homeModules.default`) — never through `nixosModules.default` or `recommendedServices`.
- GNOME/GDM configuration is not modified or removed; Hyprland is added as an additional session.
- `programs.noctalia.settings` sets only `theme.mode = "dark"` — no palette override, no wallpaper block.
- No `wayland.windowManager.hyprland` Home Manager config and no custom `hyprland.conf` — rely on Hyprland's own auto-generated default config on first login.
- `home/zircon.nix` and `homeConfigurations.zircon` (standalone HM) are not modified — Noctalia is only wired into the NixOS-integrated `home-manager.users.zircon` for `thinkpad`/`desktop`.
- `nixos-rebuild switch` is never run by an agent — it changes the running system's active generation and needs the user physically at the machine to pick/test the new GDM session. Automated verification stops at `nixos-rebuild build` (compiles the system closure without activating it).

---

### Task 1: Create the Noctalia Home Manager module

**Files:**
- Create: `home/noctalia.nix`

**Interfaces:**
- Consumes: `noctalia` flake input, passed in as a module argument (provided by Task 2's `extraSpecialArgs` wiring).
- Produces: a Home Manager module (a `{ noctalia, ... }: { ... }` function) that Task 2 adds to `home-manager.users.zircon`'s `imports` list via the path `./home/noctalia.nix`.

- [ ] **Step 1: Write the module**

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

- [ ] **Step 2: Verify syntax**

Run: `nix-instantiate --parse home/noctalia.nix`
Expected: prints the parsed expression back out with no syntax errors (this only checks parsing — it cannot evaluate `noctalia.homeModules.default` yet since the module isn't wired to the flake input until Task 2).

- [ ] **Step 3: Commit**

```bash
git add home/noctalia.nix
git commit -m "$(cat <<'EOF'
Add Noctalia Home Manager module

Enables programs.noctalia with dark-mode theming and a user systemd
service. Not yet wired into any host — flake.nix threads the noctalia
input into this module next.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Wire the `noctalia` flake input into `flake.nix`

**Files:**
- Modify: `flake.nix`

**Interfaces:**
- Consumes: `home/noctalia.nix` (Task 1) — added to `home-manager.users.zircon.imports`.
- Produces: the `noctalia` input, available as an `extraSpecialArgs` module argument to `thinkpad` and `desktop` Home Manager configs (this is what `home/noctalia.nix`'s `{ noctalia, ... }` argument resolves to at build time).

- [ ] **Step 1: Add the flake input**

In the `inputs` attrset, add (after `sops-nix`):

```nix
    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };
```

- [ ] **Step 2: Capture `noctalia` in the outputs function**

Change:

```nix
  outputs =
    {
      nixpkgs,
      home-manager,
      sops-nix,
      ...
    }:
```

to:

```nix
  outputs =
    {
      nixpkgs,
      home-manager,
      sops-nix,
      noctalia,
      ...
    }:
```

- [ ] **Step 3: Wire `thinkpad`'s Home Manager block**

Change the `thinkpad` `nixosConfigurations` entry's home-manager module block from:

```nix
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.zircon = import ./home/zircon.nix;
          }
```

to:

```nix
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit noctalia; };
            home-manager.users.zircon = {
              imports = [
                ./home/zircon.nix
                ./home/noctalia.nix
              ];
            };
          }
```

- [ ] **Step 4: Wire `desktop`'s Home Manager block the same way**

Apply the identical change from Step 3 to the `desktop` `nixosConfigurations` entry's home-manager module block.

- [ ] **Step 5: Verify the flake evaluates**

Run: `nix flake check`
Expected: completes without errors (this evaluates all three `nixosConfigurations` and `homeConfigurations.zircon`; it will fail loudly if the input, `extraSpecialArgs`, or import wiring is wrong). It's fine if it prints unrelated pre-existing warnings — there should be no new errors referencing `flake.nix`, `noctalia`, or `home/noctalia.nix`.

- [ ] **Step 6: Commit**

```bash
git add flake.nix
git commit -m "$(cat <<'EOF'
Thread noctalia flake input into thinkpad/desktop Home Manager

Adds the noctalia input and passes it via extraSpecialArgs so
home/noctalia.nix (added in the previous commit) can import
noctalia.homeModules.default for the zircon user on both hosts.
Standalone homeConfigurations.zircon is untouched.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Enable Hyprland + recommended services on `thinkpad`

**Files:**
- Modify: `configurations/thinkpad/configuration.nix`

**Interfaces:**
- Consumes: nothing from other tasks (system-level config, independent of the Home Manager wiring).
- Produces: a Hyprland session selectable at GDM, plus the services/cache Noctalia's docs recommend, for `thinkpad` only.

- [ ] **Step 1: Add Hyprland + services + binary cache**

In `configurations/thinkpad/configuration.nix`, after the existing `services.desktopManager.gnome.enable = true;` line, add:

```nix
  # Hyprland session for Noctalia (home/noctalia.nix); GDM keeps offering
  # GNOME as well, so this is purely additive.
  programs.hyprland.enable = true;

  # Noctalia's recommended services (NetworkManager and Bluetooth are
  # already enabled via common/base.nix and common/logitech.nix).
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;

  nix.settings = {
    extra-substituters = [ "https://noctalia.cachix.org" ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };
```

- [ ] **Step 2: Verify syntax**

Run: `nix-instantiate --parse configurations/thinkpad/configuration.nix`
Expected: no syntax errors.

- [ ] **Step 3: Build (do not switch)**

Run: `nixos-rebuild build --flake .#thinkpad`
Expected: builds successfully (downloads/builds Hyprland, Noctalia, and their dependencies). This only produces a `result` symlink in the current directory — it does not activate anything or touch the running system. If this is being run on a machine other than the real `thinkpad`, the build can still succeed (it only needs `/etc/nixos/hardware-configuration.nix` to exist on the build host, per this repo's existing pattern of reading that path unconditionally for whichever configuration is being built) — if it fails specifically because of missing hardware-specific info, note that in your report and move on; that failure mode is pre-existing and unrelated to this change. Clean up afterward: `rm -f result`.

- [ ] **Step 4: Commit**

```bash
git add configurations/thinkpad/configuration.nix
git commit -m "$(cat <<'EOF'
Enable Hyprland + Noctalia's recommended services on thinkpad

Adds programs.hyprland.enable (an additive GDM session alongside the
existing GNOME one), power-profiles-daemon, upower, and the Noctalia
binary cache substituter.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Enable Hyprland + recommended services on `desktop`

**Files:**
- Modify: `configurations/desktop/configuration.nix`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: the same Hyprland/services/cache setup as Task 3, for `desktop`.

- [ ] **Step 1: Add Hyprland + services + binary cache**

In `configurations/desktop/configuration.nix`, after the existing `services.desktopManager.gnome.enable = true;` line, add the identical block from Task 3, Step 1:

```nix
  # Hyprland session for Noctalia (home/noctalia.nix); GDM keeps offering
  # GNOME as well, so this is purely additive.
  programs.hyprland.enable = true;

  # Noctalia's recommended services (NetworkManager and Bluetooth are
  # already enabled via common/base.nix and common/logitech.nix).
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;

  nix.settings = {
    extra-substituters = [ "https://noctalia.cachix.org" ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };
```

- [ ] **Step 2: Verify syntax**

Run: `nix-instantiate --parse configurations/desktop/configuration.nix`
Expected: no syntax errors.

- [ ] **Step 3: Build (do not switch)**

Run: `nixos-rebuild build --flake .#desktop`
Expected: same as Task 3 Step 3. Clean up afterward: `rm -f result`.

- [ ] **Step 4: Commit**

```bash
git add configurations/desktop/configuration.nix
git commit -m "$(cat <<'EOF'
Enable Hyprland + Noctalia's recommended services on desktop

Same additive Hyprland/services/cache setup as thinkpad: GDM keeps
offering GNOME alongside the new Hyprland session.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Full-repo validation and manual test handoff

**Files:** none (verification only; no commit).

**Interfaces:**
- Consumes: the completed state of Tasks 1-4.
- Produces: a pass/fail report and manual test instructions for the user.

- [ ] **Step 1: Full flake check**

Run: `nix flake check`
Expected: no errors.

- [ ] **Step 2: Build both hosts**

Run: `nixos-rebuild build --flake .#thinkpad && rm -f result`
Run: `nixos-rebuild build --flake .#desktop && rm -f result`
Expected: both succeed.

- [ ] **Step 3: Hand off manual switch + login test to the user**

This step is manual and must not be automated — it changes the active
system generation and requires physically logging in to verify a GUI
session. Report to the user:

> Automated build verification passed for both hosts. To actually try
> Noctalia:
> 1. On each machine, run `sudo nixos-rebuild switch --flake .#<host>`
>    (or `scripts/rebuild.sh <host>`).
> 2. Log out of the current GNOME session.
> 3. At the GDM login screen, use the session-picker (gear icon) to
>    select the Hyprland session, then log in.
> 4. Confirm the Noctalia bar/launcher/dock appear.
> 5. Log out and back into GNOME to confirm it still works unchanged.

## Self-Review Notes

- **Spec coverage:** flake wiring (Task 2), host-level Hyprland/services/cache on both hosts (Tasks 3-4), the Home Manager module with dark-mode-only theme and no wallpaper (Task 1), and the explicit no-custom-Hyprland-config / no-GNOME-removal constraints (Global Constraints, and simply never touched in any task) are all covered. The testing plan from the spec maps to Task 5.
- **Placeholder scan:** no TBD/TODO; every step has literal file contents or literal commands.
- **Type/interface consistency:** `home/noctalia.nix` expects a `noctalia` argument; Task 2's `extraSpecialArgs = { inherit noctalia; }` supplies exactly that name on both hosts. The import path `./home/noctalia.nix` used in Task 2 matches the file Task 1 creates.
