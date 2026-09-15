# domain is passed in directly (not a secret); only the account password is
# sops-sourced. Provider is hardcoded since this host only updates Namecheap.
{ domain }:
{ config, pkgs, ... }:

{
  environment.systemPackages = [ pkgs.ddns-updater ];

  sops.secrets."ddns_updater_secrets/password" = { };

  # ddns-updater's systemd unit hardcodes DynamicUser, so sops-nix can't chown
  # this file to the service's (unpredictable, per-boot) user at activation
  # time — mode 0444 keeps it readable by that user without a service override.
  sops.templates."ddns-updater-config" = {
    mode = "0444";
    content = builtins.toJSON {
      settings = [
        {
          provider = "namecheap";
          inherit domain;
          password = config.sops.placeholder."ddns_updater_secrets/password";
        }
      ];
    };
  };

  services.ddns-updater = {
    enable = true;
    environment = {
      SERVER_ENABLED = "yes";
      CONFIG_FILEPATH = config.sops.templates."ddns-updater-config".path;
      PERIOD = "1m";
      LOG_LEVEL = "debug";
      LISTENING_ADDRESS = ":8081";
    };
  };
}
