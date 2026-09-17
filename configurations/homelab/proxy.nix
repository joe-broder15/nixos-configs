{
  config,
  lib,
  baseDomain,
  ...
}:

let
  mkProxy = proxyPass: {
    forceSSL = true;
    useACMEHost = baseDomain; # all vhosts share the one wildcard cert keyed by baseDomain below
    locations."/" = {
      inherit proxyPass;
      proxyWebsockets = true;
    };
  };

  localProxy = port: mkProxy "http://127.0.0.1:${toString port}";

  # Simple vhosts: just proxy to a local port, no extra nginx config needed.
  simplePorts = {
    plex = 32400; # Plex's fixed default port
    resilio = 9999; # must match configuration.nix's services.resilio.httpListenPort
    ddns = 8081; # common/namecheap-ddns-updater.nix's LISTENING_ADDRESS
  };
in
{
  # ACME DNS-01 challenge credentials — separate from the ddns-updater's own
  # namecheap secret in common/namecheap-ddns-updater.nix (different purpose).
  sops.secrets."namecheap_secrets/namecheap_api_user" = { };
  sops.secrets."namecheap_secrets/namecheap_api_key" = { };

  sops.templates."namecheap.env" = {
    owner = "acme"; # the acme service runs as its own user and needs to read this file
    content = ''
      NAMECHEAP_API_USER=${config.sops.placeholder."namecheap_secrets/namecheap_api_user"}
      NAMECHEAP_API_KEY=${config.sops.placeholder."namecheap_secrets/namecheap_api_key"}
    '';
  };

  services.nginx.enable = true;
  services.nginx.recommendedProxySettings = true;

  security.acme = {
    acceptTerms = true;
    defaults.email = "joe.broder@proton.me";

    # One cert object for the base zone, requesting a wildcard
    certs."${baseDomain}" = {
      domain = "*.${baseDomain}";
      extraDomainNames = [ baseDomain ]; # also cover apex
      dnsProvider = "namecheap"; # lego provider code
      environmentFile = config.sops.templates."namecheap.env".path;

      # Make the resulting cert readable by nginx
      group = config.services.nginx.group;
    };
  };

  services.nginx.virtualHosts =
    lib.mapAttrs' (name: port: lib.nameValuePair "${name}.${baseDomain}" (localProxy port)) simplePorts
    // {
      # homer.nix's services.homer module already creates this vhost's serving
      # config (virtualHost.nginx.enable); this entry only adds TLS to it.
      "homer.${baseDomain}" = {
        useACMEHost = baseDomain;
        forceSSL = true;
      };

      "qbittorrent.${baseDomain}" = lib.recursiveUpdate (localProxy 8082) {
        locations."/".extraConfig = ''
          # If you see timeouts on large responses:
          proxy_read_timeout 300s;
          proxy_send_timeout 300s;
        '';
      };

      "openwebui.${baseDomain}" = lib.recursiveUpdate (localProxy 8080) {
        locations."/".extraConfig = ''
          # Streaming responses (SSE) must not be buffered or they arrive garbled/delayed.
          proxy_buffering off;
          proxy_cache off;

          # LLM completions can run long; keep the connection open.
          proxy_read_timeout 1800s;
          proxy_send_timeout 1800s;
          proxy_connect_timeout 1800s;
        '';
      };

      "proxmox.${baseDomain}" = lib.recursiveUpdate (mkProxy "https://192.168.1.100:8006") {
        locations."/".extraConfig = ''
          # Proxmox upstream commonly uses a self-signed TLS certificate.
          proxy_ssl_verify off;
        '';
      };
    };
}
