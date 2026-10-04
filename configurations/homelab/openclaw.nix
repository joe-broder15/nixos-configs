# OpenClaw AI assistant gateway (github:openclaw/nix-openclaw), run as a
# system service via its NixOS module rather than the upstream Home Manager
# template, since homelab has no Home Manager. Talks to Discord (DMs from one
# sops-held user ID only) and uses the ChatGPT Pro subscription through Codex
# OAuth.
{
  config,
  lib,
  pkgs,
  openclawPkgs, # nix-openclaw's packages.${system}, from flake.nix specialArgs
  ...
}:

let
  cfg = config.services.openclaw-gateway;

  runtimePlugins = [
    "discord"
    "codex" # ChatGPT/Codex subscription auth for openai/* models
  ];

  workspaceDir = "${cfg.stateDir}/workspace";

  # Repo-managed workspace files, symlinked into the otherwise-writable
  # workspace (OpenClaw keeps its own memory/notes alongside them).
  workspaceFiles = {
    "AGENTS.md" = ./openclaw/AGENTS.md;
    "SOUL.md" = ./openclaw/SOUL.md;
    "TOOLS.md" = ./openclaw/TOOLS.md;
    "IDENTITY.md" = ./openclaw/IDENTITY.md;
    "USER.md" = ./openclaw/USER.md;
  };

  envFile = config.sops.templates."openclaw.env".path;

  # Runs the openclaw CLI as the service user with the service's config, state
  # and secrets, e.g. `sudo openclaw-cli models auth login --provider openai --device-code`.
  openclawCli = pkgs.writeShellScriptBin "openclaw-cli" ''
    if [ "$(id -u)" -ne 0 ]; then
      exec sudo "$0" "$@"
    fi
    set -a
    . ${envFile}
    set +a
    cd ${cfg.stateDir}
    exec ${pkgs.util-linux}/bin/runuser -u ${cfg.user} -- \
      env HOME=${cfg.stateDir} \
        OPENCLAW_CONFIG_PATH=${cfg.configPath} \
        OPENCLAW_STATE_DIR=${cfg.stateDir} \
        ${cfg.package}/bin/openclaw "$@"
  '';
in
{
  sops.secrets."openclaw_secrets/discord_bot_token" = { };
  # Numeric Discord user ID (Developer Mode → right-click yourself → Copy User
  # ID); not a credential, just kept out of the repo.
  sops.secrets."openclaw_secrets/discord_allowed_user_id" = { };
  sops.secrets."openclaw_secrets/gateway_token" = { };

  # Secrets reach the gateway as env vars, referenced from the config below as
  # env SecretRefs or ${VAR} substitutions, so they never land in the
  # world-readable Nix store.
  sops.templates."openclaw.env" = {
    owner = cfg.user;
    restartUnits = [ "${cfg.unitName}.service" ];
    content = ''
      DISCORD_BOT_TOKEN=${config.sops.placeholder."openclaw_secrets/discord_bot_token"}
      DISCORD_ALLOWED_USER_ID=${config.sops.placeholder."openclaw_secrets/discord_allowed_user_id"}
      OPENCLAW_GATEWAY_TOKEN=${config.sops.placeholder."openclaw_secrets/gateway_token"}
    '';
  };

  services.openclaw-gateway = {
    enable = true;
    package = openclawPkgs.openclaw;
    environmentFiles = [ envFile ];
    environment = {
      HOME = cfg.stateDir;
      # Matches what the Home Manager module sets when runtime plugins are
      # loaded from Nix store paths instead of `openclaw plugins install`.
      OPENCLAW_DISABLE_PERSISTED_PLUGIN_REGISTRY = "1";
    };

    config = {
      gateway = {
        mode = "local";
        bind = "loopback"; # no inbound access; manage over SSH
        auth = {
          mode = "token";
          token = {
            source = "env";
            provider = "default";
            id = "OPENCLAW_GATEWAY_TOKEN";
          };
        };
      };

      # External runtime plugins, loaded from Nix-built store paths; the Home
      # Manager module's runtimePlugins option does exactly this under the hood.
      plugins = {
        load.paths = map (id: "${openclawPkgs."openclaw-runtime-plugin-${id}"}") runtimePlugins;
        entries = lib.genAttrs runtimePlugins (_: {
          enabled = true;
        });
      };

      agents.defaults = {
        workspace = workspaceDir;
        # Workspace files come from this repo; don't let OpenClaw seed its own.
        skipBootstrap = true;
        model.primary = "openai/gpt-6-astra";
      };

      channels.discord = {
        enabled = true;
        token = {
          source = "env";
          provider = "default";
          id = "DISCORD_BOT_TOKEN";
        };
        dmPolicy = "allowlist";
        # OpenClaw expands ${VAR} in config strings at load time; if it is unset
        # the allowlist is empty and nobody can DM the bot.
        allowFrom = [ "\${DISCORD_ALLOWED_USER_ID}" ];
        groupPolicy = "disabled"; # DMs only; ignore all servers
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d ${workspaceDir} 0750 ${cfg.user} ${cfg.group} - -"
  ]
  ++ lib.mapAttrsToList (name: src: "L+ ${workspaceDir}/${name} - - - - ${src}") workspaceFiles;

  environment.systemPackages = [ openclawCli ];
}
