{
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ../common/base.nix
    ../common/crypto.nix
    ../common/synology.nix
    ./domain.nix
    ./proxy.nix
    ./homer.nix
    (import ../common/namecheap-ddns-updater.nix { domain = "ddns.clubtropicalexcellent.vip"; })
    (import ../common/wireguard.nix {
      secretKey = "wireguard_secrets/homelab_proton_vpn_config";
      natExternalInterface = "ens18";
    })
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

  environment.systemPackages = with pkgs; [
    vim
    wget
    qbittorrent
    plex
    htop
    fastfetch
    git
    tree
    tmux
    homer
    sillytavern
    resilio-sync
    clamav
    age
  ];

  services = {
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
}
