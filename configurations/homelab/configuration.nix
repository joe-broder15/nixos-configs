{
  pkgs,
  ...
}:

{
  imports = [
    ../common/base.nix
    ../common/crypto.nix
    ../common/synology.nix
    # domain.nix supplies the baseDomain module arg consumed by proxy.nix and homer.nix.
    ./domain.nix
    ./proxy.nix
    ./homer.nix
    (import ../common/namecheap-ddns-updater.nix { domain = "ddns.clubtropicalexcellent.vip"; })
    (import ../common/wireguard.nix {
      secretKey = "wireguard_secrets/homelab_proton_vpn_config";
      # Unlike thinkpad, homelab routes other hosts' traffic out through the
      # tunnel, so NAT is enabled on ens18 (this host's WAN-facing interface).
      natExternalInterface = "ens18";
    })
  ];

  networking.hostName = "homelab-nixos";

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda"; # this host's boot disk
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
    resilio-sync
    clamav
    age
  ];

  services = {
    openssh = {
      enable = true;
    };

    # qbittorrent/plex all run as the single "user" account declared below,
    # rather than each getting a dedicated service user.
    qbittorrent = {
      enable = true;
      openFirewall = true;
      user = "user";
      webuiPort = 8082; # must match proxy.nix's simplePorts.qbittorrent
    };

    plex = {
      enable = true;
      user = "user";
      openFirewall = true; # opens Plex's fixed default port (32400)
    };

    resilio = {
      enable = true;
      enableWebUI = true;
      httpListenAddr = "127.0.0.1"; # localhost-only; proxy.nix exposes it externally
      httpListenPort = 9999; # must match proxy.nix's simplePorts.resilio
      directoryRoot = "/resilio-shared-folders"; # created below via tmpfiles, owned by rslsync
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
      loadModels = [ "deepseek-r1:1.5b" ]; # small enough to run tolerably CPU-only
    };

    open-webui.enable = true; # finds Ollama automatically at its default localhost:11434 API
  };

  networking.firewall = {
    enable = true;
    # Plex and qBittorrent aren't listed here — they open their own ports via
    # their services.*.openFirewall option instead.
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
      "wheel" # sudo access; convenience for this shared homelab account
    ];
  };

  # rslsync user/group are created automatically by the resilio module.
  systemd.tmpfiles.rules = [
    "d /resilio-shared-folders 0750 rslsync rslsync -"
  ];
}
