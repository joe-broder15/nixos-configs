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
              url = "https://qBittorrent.local.clubtropicalexcellent.vip";

            }
            {
              name = "SillyTavern";
              url = "https://sillytavern.local.clubtropicalexcellent.vip";
            }
          ];
        }
      ];
    };
  };
}
