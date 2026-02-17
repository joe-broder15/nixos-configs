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
      logo = "assets/hibiscus.png";
      columns = "1";
      services = [
        {
          name = "Services";
          items = [
            {
              name = "Plex";
              url = "https://plex.local.clubtropicalexcellent.vip";
              type = "Plex";
              # logo = "assets/tools/sample.png";
              # token= "<---insert-plex-token-here--->";
            }
            {
              name = "qBittorrent";
              type = "qBittorrent";
              rateInterval = 2000;
              torrentInterval = 5000;
              url = "https://qbittorrent.local.clubtropicalexcellent.vip";
            }
          ];
        }
      ];
    };
  };
}
