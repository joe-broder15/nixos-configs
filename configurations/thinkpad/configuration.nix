{ config, pkgs, ... }:

{
  imports = [
    ./hosts.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Los_Angeles";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  services.printing.enable = true;

  services.openssh = {
    generateHostKeys = true;
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };

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
      "rslsync"
    ];
  };

  programs.firefox.enable = true;

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    zsh
    resilio-sync
    home-manager
    gnome-tweaks
    cifs-utils
    age
    sops
  ];

  services.resilio = {
    enable = true;
    enableWebUI = true;
    httpListenAddr = "127.0.0.1";
    httpListenPort = 9999;
    directoryRoot = "/resilio-shared-folders";
  };

  # rslsync creates this dir as 0755 by default; setgid + group-write lets the
  # zircon user (in the rslsync group) read and write synced files directly.
  systemd.tmpfiles.rules = [
    "d /resilio-shared-folders 2775 rslsync rslsync - -"
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  fileSystems."/mnt/Library1" = {
    device = "//synology.local/Library1";
    fsType = "cifs";
    options =
      let
        automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
      in
      [ "${automount_opts},credentials=${config.sops.templates."smb-secrets".path},uid=1000,gid=100" ];
  };

  sops.defaultSopsFile = ../../secrets/common.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.secrets."smb_secrets/synology_creds/username" = { };
  sops.secrets."smb_secrets/synology_creds/password" = { };
  sops.templates."smb-secrets".content = ''
    username=${config.sops.placeholder."smb_secrets/synology_creds/username"}
    password=${config.sops.placeholder."smb_secrets/synology_creds/password"}
  '';

  # Do not change; tracks the NixOS release that initialized stateful data paths.
  system.stateVersion = "25.05";
}
