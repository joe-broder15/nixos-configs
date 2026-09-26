{ config, pkgs, ... }:

{
  environment.systemPackages = [ pkgs.cifs-utils ];

  # Static IP mapping, since .local mDNS resolution can't be relied on here.
  networking.hosts."192.168.1.99" = [ "synology.local" ];

  fileSystems."/mnt/Library1" = {
    device = "//synology.local/Library1";
    fsType = "cifs";
    options =
      let
        # Mount on first access and unmount after idling, rather than at
        # boot, so the host doesn't hang/fail boot if the NAS is unreachable.
        automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
      in
      # uid=1000 assumes the primary interactive user (zircon); gid=100 is
      # NixOS's default "users" group. x-gvfs-show lists the mount in the
      # Nautilus/GNOME sidebar; clicking it triggers the automount.
      [
        "${automount_opts},x-gvfs-show,x-gvfs-name=Library1,credentials=${
          config.sops.templates."smb-secrets".path
        },uid=1000,gid=100"
      ];
  };

  sops.secrets."smb_secrets/synology_creds/username" = { };
  sops.secrets."smb_secrets/synology_creds/password" = { };
  # mount.cifs's credentials= option needs both in one file, in this format,
  # so combine the two individually-decrypted secrets via a sops template.
  sops.templates."smb-secrets".content = ''
    username=${config.sops.placeholder."smb_secrets/synology_creds/username"}
    password=${config.sops.placeholder."smb_secrets/synology_creds/password"}
  '';
}
