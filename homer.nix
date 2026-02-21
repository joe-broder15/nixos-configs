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
              icon = "fab fa play";
              url = "https://plex.local.clubtropicalexcellent.vip";
            }
            {
              name = "qBittorrent";
              icon = "fab fa skull-crossbones";
              url = "https://qBittorrent.local.clubtropicalexcellent.vip";

            }
            {
              name = "SillyTavern";
              icon = "fab fa beer-mug-empty";
              url = "https://sillytavern.local.clubtropicalexcellent.vip";
            }
          ];
        }
      ];
    };
  };
}
