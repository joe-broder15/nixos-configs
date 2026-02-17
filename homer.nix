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
          items = [
            {
              name = "Plex";
              url = "https://plex.local.clubtropicalexcellent.vip";
            }
            {
              name = "qBittorrent";
              type = "qBittorrent";
              rateInterval = 2000;
              torrentInterval = 5000;
              url = "127.0.0.1:8082";
            }
          ];
        }
      ];
    };
  };
}
