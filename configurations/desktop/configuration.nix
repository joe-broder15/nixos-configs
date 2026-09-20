{ pkgs, config, ... }:

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
    ../common/logitech.nix
    (import ../common/wireguard.nix { secretKey = "wireguard_secrets/desktop_proton_vpn_config"; })
  ];

  networking.hostName = "desktop-nixos";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;

  # RTX 2080 Super (Turing). modesetting.enable is required for GDM/Wayland;
  # open = false since proprietary is still the recommended driver for Turing.
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

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

  programs.steam.enable = true;

  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    zsh
    home-manager
    gnome-tweaks
  ];
}
