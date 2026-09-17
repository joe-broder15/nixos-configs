# Reusable resilio-sync component: web-UI-managed (so a valid Resilio Sync
# 3.0 account license can actually be registered/verified through a browser),
# with a statically applied license and WebUI creds sourced from sops-nix.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  environment.systemPackages = [ pkgs.resilio-sync ];

  # Every file here is read by ExecStartPre commands that run as the resilio
  # service's User (rslsync, set by the upstream services.resilio module),
  # so sops-nix's default root:root 0400 leaves them unreadable there.
  sops.secrets."resilio_secrets/btskey" = {
    owner = "rslsync";
    # sops-nix names materialized secrets after their yaml key by default (no
    # extension); `rslsync --license` is only ever documented/shipped against
    # an actual *.btskey file, so materialize it as one instead.
    path = "/run/secrets/resilio_secrets/license.btskey";
  };
  # Kept around (decrypted, rslsync-owned) even though nothing here consumes
  # it directly: with the web UI enabled, the keepass shared folder has to be
  # re-added by hand through it, and this is the read/write key to paste in.
  sops.secrets."resilio_secrets/shared_folder_keepass_rw_key" = {
    owner = "rslsync";
  };
  sops.secrets."resilio_secrets/ui_username" = {
    owner = "rslsync";
  };
  sops.secrets."resilio_secrets/ui_password" = {
    owner = "rslsync";
  };

  services.resilio = {
    enable = true;
    enableWebUI = true;
    # Localhost-only; reach the WebUI via an SSH tunnel rather than exposing
    # it on the LAN.
    httpListenAddr = "127.0.0.1";
    httpListenPort = 9000;
    directoryRoot = "/resilio-shared-folders";
  };

  # The upstream module's config.json has no field for the license, and its
  # httpLogin/httpPassword options only accept plain eval-time Nix strings
  # (which would leak the sops secrets into the world-readable Nix store), so
  # both are applied out-of-band here instead, right before the daemon starts.
  # /run/rslsync/config.json mirrors the module's own internal convention
  # (RuntimeDirectory = "rslsync", config written to config.json inside it).
  systemd.services.resilio.serviceConfig.ExecStartPre =
    let
      btskeyPath = config.sops.secrets."resilio_secrets/btskey".path;
    in
    lib.mkAfter [
      (pkgs.writeShellScript "resilio-inject-webui-creds" ''
        ${lib.getExe pkgs.jq} \
          --arg login "$(cat ${config.sops.secrets."resilio_secrets/ui_username".path})" \
          --arg password "$(cat ${config.sops.secrets."resilio_secrets/ui_password".path})" \
          '.webui.login = $login | .webui.password = $password' \
          /run/rslsync/config.json >/run/rslsync/config.json.new
        mv /run/rslsync/config.json.new /run/rslsync/config.json
      '')
      # Resilio's own convention (matching its GUI builds) is a license file
      # sitting directly in a root folder, not just a transient --license
      # invocation, so place a real copy there too; mode 0440 (rather than the
      # sops secret's 0400) so anyone in the rslsync group can actually check
      # it. -C skips the rewrite when the license is unchanged, since this
      # ExecStartPre step reruns on every service (re)start.
      "${pkgs.coreutils}/bin/install -C -m 0440 ${btskeyPath} /resilio-shared-folders/license.btskey"
      "${lib.getExe pkgs.resilio-sync} --license ${btskeyPath} --config /run/rslsync/config.json"
    ];

  # rslsync creates this dir as 0755 by default; setgid + group-write lets a
  # user in the rslsync group read and write synced files directly.
  systemd.tmpfiles.rules = [
    "d /resilio-shared-folders 2775 rslsync rslsync - -"
  ];

  # Every interactive (isNormalUser) account gets read/write access to
  # /resilio-shared-folders automatically, instead of each host manually
  # listing "rslsync" in its users.users.<name>.extraGroups.
  users.groups.rslsync.members = lib.attrNames (
    lib.filterAttrs (_: u: u.isNormalUser) config.users.users
  );
}
