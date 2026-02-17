{ config, ... }:

let
  baseDomain = "local.clubtropicalexcellent.vip";
in
{
  services.nginx.enable = true;

  security.acme = {
    acceptTerms = true;
    defaults.email = "joe.broder@proton.me";

    # One cert object for the base zone, requesting a wildcard
    certs."${baseDomain}" = {
      domain = "*.${baseDomain}";
      extraDomainNames = [ baseDomain ]; # also cover apex
      dnsProvider = "namecheap"; # lego provider code
      credentialsFile = "/etc/nixos/namecheap.env";

      # Make the resulting cert readable by nginx
      group = config.services.nginx.group;
    };
  };

  # Plex host using the wildcard cert
  services.nginx.virtualHosts."plex.${baseDomain}" = {
    forceSSL = true;
    useACMEHost = baseDomain;
    locations."/" = {
      proxyPass = "http://127.0.0.1:32400";
      proxyWebsockets = true;
    };
  };

  # qBittorrent host using the wildcard cert
  services.nginx.virtualHosts."qbittorrent.${baseDomain}" = {
    forceSSL = true;
    useACMEHost = baseDomain;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8082";
      proxyWebsockets = true;
      extraConfig = ''
        # qBittorrent WebUI is sensitive to headers; these help:
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Real-IP $remote_addr;

        # If you see timeouts on large responses:
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
      '';
    };
  };

  # Homer host using the wildcard cert
  services.nginx.virtualHosts."homer.${baseDomain}" = {
    useACMEHost = baseDomain;
    forceSSL = true;
  };
}
