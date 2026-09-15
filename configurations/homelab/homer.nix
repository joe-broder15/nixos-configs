{ baseDomain, ... }:

let
  logo = name: "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/${name}.png";
in
{
  services.homer = {
    enable = true;
    virtualHost = {
      domain = "homer.${baseDomain}";
      nginx.enable = true;
    };
    settings = {
      title = "Club Tropical Excellent";
      subtitle = "Now on NixOS!";
      columns = "1";
      services = [
        {
          name = "Services";
          icon = "fas fa-server";
          items = [
            {
              name = "Plex";
              logo = logo "plex";
              url = "https://plex.${baseDomain}";
            }
            {
              name = "AnimeZ";
              icon = "fas fa-tv";
              url = "https://animez.to";
            }
            {
              name = "qBittorrent";
              logo = logo "qbittorrent";
              url = "https://qbittorrent.${baseDomain}";
            }
            {
              name = "SillyTavern";
              logo = logo "sillytavern";
              url = "https://sillytavern.${baseDomain}";
            }
            {
              name = "Resilio Sync";
              logo = logo "resiliosync";
              url = "https://resilio.${baseDomain}";
            }
            {
              name = "DDNS Updater";
              logo = logo "ddns-updater";
              url = "https://ddns.${baseDomain}";
            }
            {
              name = "Open WebUI";
              logo = logo "open-webui";
              url = "https://openwebui.${baseDomain}";
            }
            {
              name = "Proxmox";
              logo = logo "proxmox";
              url = "https://proxmox.${baseDomain}";
            }
            {
              name = "Router";
              logo = logo "router";
              url = "http://192.168.1.1";
            }
          ];
        }
      ];
    };
  };
}
