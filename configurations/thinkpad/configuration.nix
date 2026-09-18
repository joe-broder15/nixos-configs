{ pkgs, ... }:

{
  imports = [
    ../common/base.nix
    ../common/crypto.nix
    ../common/synology.nix
    ../common/resilio.nix
    ../common/hosts.nix
    ../common/logitech.nix
    # No natExternalInterface: this laptop is only ever a wg0 client, never a gateway for other hosts.
    (import ../common/wireguard.nix { secretKey = "wireguard_secrets/thinkpad_proton_vpn_config"; })
  ];

  networking.hostName = "thinkpad-nixos";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

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
