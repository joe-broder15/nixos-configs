{
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ../common/crypto.nix
    ../common/synology.nix
    ./domain.nix
    ./proxy.nix
    ./homer.nix
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    vim
    wget
    qbittorrent
    wireguard-tools
    plex
    htop
    fastfetch
    git
    tree
    tmux
    ddns-updater
    homer
    sillytavern
    resilio-sync
    clamav
    age
  ];

  networking = {
    hostName = "nixos";
    networkmanager.enable = true;
    wg-quick.interfaces.wg0.configFile = "/etc/nixos/wireguard/wg0.conf";
    nat = {
      enable = true;
      enableIPv6 = true;
      externalInterface = "ens18";
      internalInterfaces = [ "wg0" ];
    };
  };

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

  services = {
    xserver = {
      xkb = {
        layout = "us";
        variant = "";
      };
    };

    openssh = {
      enable = true;
    };

    qbittorrent = {
      enable = true;
      openFirewall = true;
      user = "user";
      webuiPort = 8082;
    };

    plex = {
      enable = true;
      user = "user";
      openFirewall = true;
    };

    ddns-updater = {
      enable = true;
      environment = {
        SERVER_ENABLED = "yes";
        CONFIG_FILEPATH = "/etc/ddns-updater/config.json";
        PERIOD = "1m";
        LOG_LEVEL = "debug";
        LISTENING_ADDRESS = ":8081";
      };
    };

    sillytavern = {
      enable = true;
      port = 8083;
      listen = true;
      user = "user";
    };

    resilio = {
      enable = true;
      enableWebUI = true;
      httpListenAddr = "127.0.0.1";
      httpListenPort = 9999;
      directoryRoot = "/resilio-shared-folders";
    };

    clamav = {
      scanner.enable = true;
      daemon.enable = true;
    };

    # CPU-only until a GPU is available; swap to pkgs.ollama for GPU acceleration.
    ollama = {
      enable = true;
      package = pkgs.ollama-cpu;
      host = "0.0.0.0";
      openFirewall = true;
      loadModels = [ "deepseek-r1:1.5b" ];
    };

    open-webui.enable = true;
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      80 # HTTP — nginx redirects to HTTPS
      443 # HTTPS — nginx
      22 # SSH
      8080 # Open WebUI
      11434 # Ollama API — also opened by services.ollama.openFirewall
    ];
  };

  users.users.user = {
    isNormalUser = true;
    description = "user";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  systemd.tmpfiles.rules = [
    "d /resilio-shared-folders 0750 rslsync rslsync -"
  ];

  # The upstream sillytavern module symlinks config.yaml into the read-only Nix
  # store, which prevents SillyTavern from writing its own config at runtime.
  # We clear that tmpfiles rule and replace any symlink with a writable copy on
  # every service start.
  systemd.tmpfiles.settings.sillytavern."/var/lib/SillyTavern/config.yaml" = lib.mkForce { };

  systemd.services.sillytavern.preStart = ''
    if [ -L /var/lib/SillyTavern/config.yaml ] || [ ! -e /var/lib/SillyTavern/config.yaml ]; then
      rm -f /var/lib/SillyTavern/config.yaml
      cp ${pkgs.sillytavern}/lib/node_modules/sillytavern/default/config.yaml /var/lib/SillyTavern/config.yaml
      chmod 600 /var/lib/SillyTavern/config.yaml
    fi
  '';

  # Do not change; tracks the NixOS release that initialized stateful data paths.
  system.stateVersion = "25.05";
}
