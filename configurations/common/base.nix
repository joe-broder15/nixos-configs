{
  # networking.hostName is set per-host in each configuration.nix.
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

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Required since this repo's configs are consumed as flake outputs.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Needed for unfree packages like resilio-sync (common/resilio.nix).
  nixpkgs.config.allowUnfree = true;

  # Do not change; tracks the NixOS release that initialized stateful data paths.
  system.stateVersion = "25.05";
}
