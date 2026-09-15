{ config, pkgs, ... }:

{
  environment.systemPackages = [ pkgs.cifs-utils ];

  networking.hosts."192.168.1.99" = [ "synology.local" ];

  fileSystems."/mnt/Library1" = {
    device = "//synology.local/Library1";
    fsType = "cifs";
    options =
      let
        automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
      in
      [ "${automount_opts},credentials=${config.sops.templates."smb-secrets".path},uid=1000,gid=100" ];
  };

  sops.secrets."smb_secrets/synology_creds/username" = { };
  sops.secrets."smb_secrets/synology_creds/password" = { };
  sops.templates."smb-secrets".content = ''
    username=${config.sops.placeholder."smb_secrets/synology_creds/username"}
    password=${config.sops.placeholder."smb_secrets/synology_creds/password"}
  '';
}
