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

  # WORKAROUND for https://github.com/openclaw/nix-openclaw/issues/158 — delete
  # once fixed. OpenClaw only grants plugins keyed-store access (which discord
  # and codex need) if they're bundled or have an official npm install record,
  # and Nix-loaded plugins have neither. So copy the gateway and drop the
  # Nix-built, hash-pinned official plugins into its own bundled extensions
  # dir, where they load with origin "bundled". A real copy is needed because
  # OpenClaw resolves its package root through symlinks.
  #
  # Each plugin's node_modules is moved outside dist/ (dist-runtime is a
  # symlink to it) and linked back: OpenClaw's ESM fast-path resolver forces
  # every relative ./x.js import under dist/ to load as ESM, which breaks CJS
  # deps such as discord-api-types. Node resolves deps by realpath, so the
  # hook no longer sees them.
  gatewayWithPlugins =
    let
      gateway = openclawPkgs.openclaw-gateway;
    in
    pkgs.runCommand "openclaw-gateway-bundled-${gateway.version}" { } ''
      cp -a ${gateway} $out
      chmod -R u+w $out
      substituteInPlace $out/bin/openclaw --replace-fail ${gateway} $out
      ext=$out/lib/node_modules/openclaw/dist/extensions
      deps=$out/lib/openclaw-plugin-deps
      ${lib.concatMapStrings (id: ''
        cp -a ${openclawPkgs."openclaw-runtime-plugin-${id}"} $ext/${id}
        chmod -R u+w $ext/${id}
        if [ -L $ext/${id}/node_modules/openclaw ]; then
          ln -sfn $out/lib/openclaw $ext/${id}/node_modules/openclaw
        fi
        if [ -d $ext/${id}/node_modules ]; then
          mkdir -p $deps/${id}
          mv $ext/${id}/node_modules $deps/${id}/node_modules
          ln -s $deps/${id}/node_modules $ext/${id}/node_modules
        fi
      '') runtimePlugins}
    '';

  # nix-openclaw's batteries-included `openclaw` wrapper (extra tool CLIs on
  # PATH), re-pointed at the gateway above.
  openclawPackage = pkgs.runCommand "openclaw-bundled-${openclawPkgs.openclaw-gateway.version}" { } ''
    mkdir -p $out/bin
    substitute ${openclawPkgs.openclaw}/bin/openclaw $out/bin/openclaw \
      --replace-fail ${openclawPkgs.openclaw-gateway} ${gatewayWithPlugins}
    chmod +x $out/bin/openclaw
  '';

  workspaceDir = "${cfg.stateDir}/workspace";

  # Repo-managed workspace files, symlinked into the otherwise-writable
  # workspace (OpenClaw keeps its own memory/notes alongside them).
  workspaceFiles = {
    "AGENTS.md" = ./openclaw/AGENTS.md;
    "SOUL.md" = ./openclaw/SOUL.md;
    "IDENTITY.md" = ./openclaw/IDENTITY.md;
  };

  # USER.md is the agent's own memory of the user (it rewrites it as it
  # learns), so it's only seeded from the repo when missing, never managed.
  # Also clears leftover read-only store symlinks from files that used to be
  # managed: USER.md, and TOOLS.md (retired by OpenClaw; its notes now live in
  # AGENTS.md's ## Tools section).
  prepareWorkspace = pkgs.writeShellScript "openclaw-prepare-workspace" ''
    for f in USER.md TOOLS.md; do
      if [ -L ${workspaceDir}/$f ]; then
        rm ${workspaceDir}/$f
      fi
    done
    if [ ! -e ${workspaceDir}/USER.md ]; then
      install -m 0640 ${./openclaw/USER.md} ${workspaceDir}/USER.md
    fi
  '';

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
    package = openclawPackage;
    environmentFiles = [ envFile ];
    environment.HOME = cfg.stateDir;
    execStartPre = [ "${prepareWorkspace}" ];

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

      # Bundled into the gateway above, so they only need enabling.
      plugins.entries = lib.genAttrs runtimePlugins (_: {
        enabled = true;
      });

      agents.defaults = {
        workspace = workspaceDir;
        # Workspace files come from this repo; don't let OpenClaw seed its own.
        skipBootstrap = true;
        model.primary = "openai/gpt-5.6-sol";
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
