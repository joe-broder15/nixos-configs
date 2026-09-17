{ pkgs, ... }:

# Same desktop-class profile as ../thinkpad/configuration.nix (GNOME desktop,
# Resilio Sync, Synology mount), for a separate physical machine — only the
# WireGuard secret differs.
{
  imports = [
    ../common/base.nix
    ../common/crypto.nix
    ../common/synology.nix
    ../common/resilio.nix
    ../common/hosts.nix
    (import ../common/wireguard.nix { secretKey = "wireguard_secrets/desktop_proton_vpn_config"; })
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  services.printing.enable = true;

  security.rtkit.enable = true;
  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  users.users.zircon = {
    isNormalUser = true;
    description = "zircon";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  programs.firefox.enable = true;

  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    zsh
    home-manager
    gnome-tweaks
    age
    sops
  ];
}
