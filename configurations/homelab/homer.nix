{ ... }:

{
  services.homer = {
    enable = true;
    virtualHost = {
      domain = "homer.local.clubtropicalexcellent.vip";
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
              logo = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/plex.png";
              url = "https://plex.local.clubtropicalexcellent.vip";
            }
            {
              name = "qBittorrent";
              logo = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/qbittorrent.png";
              url = "https://qBittorrent.local.clubtropicalexcellent.vip";

            }
            {
              name = "SillyTavern";
              logo = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/sillytavern.png";
              url = "https://sillytavern.local.clubtropicalexcellent.vip";
            }
            {
              name = "Resilio Sync";
              logo = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/resiliosync.png";
              url = "https://resilio.local.clubtropicalexcellent.vip";
            }
            {
              name = "DDNS Updater";
              logo = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/ddns-updater.png";
              url = "https://ddns.local.clubtropicalexcellent.vip";
            }
            {
              name = "Proxmox";
              logo = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/proxmox.png";
              url = "https://proxmox.local.clubtropicalexcellent.vip";
            }
          ];
        }
      ];
    };
  };
}
