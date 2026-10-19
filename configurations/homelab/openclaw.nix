# OpenClaw gateway as a system service, via nix-openclaw's NixOS module
# (services.openclaw-gateway, wired in by flake.nix), running as `user` with
# state in ~user/.openclaw. That module is thinner than nix-openclaw's Home
# Manager one, so the parts of it this setup relies on (Nix mode, workspace
# bootstrap files, the Codex tools profile) are reproduced here. The model runs
# on the Codex harness, signed in to ChatGPT (no API key), and the gateway
# talks to Discord, answering only one allowlisted user; secrets are in sops.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  homeDir = config.users.users.user.home;
  stateDir = "${homeDir}/.openclaw";
  workspaceDir = "${stateDir}/workspace";

  # Official plugins bundled into the gateway below: Discord for the channel,
  # Codex for the agent runtime (it ships its own pinned, static Codex binary).
  bundledPlugins = [
    "discord"
    "codex"
  ];

  # Workaround for nix-openclaw#158 (accepted risk): loaded via runtimePlugins
  # (plugins.load.paths), these plugins have no install record, so OpenClaw
  # treats them as untrusted and refuses the keyed storage they need at
  # registration. Plugins inside the gateway package's own dist/extensions
  # count as "bundled" and are trusted, so copy the gateway and add
  # nix-openclaw's hash-pinned builds of the official @openclaw/* packages
  # there. This grants those plugins trust without OpenClaw's provenance check;
  # only ever put official packages here. A full copy is needed because
  # OpenClaw resolves its package root through symlinks and rejects
  # out-of-package bundled-dir overrides. Drop this once #158 is fixed.
  gatewayWithPlugins =
    pkgs.runCommand "openclaw-gateway-with-plugins-${pkgs.openclaw-gateway.version}" { }
      ''
        cp -a ${pkgs.openclaw-gateway} $out
        chmod -R u+w $out
        root=$out/lib/node_modules/openclaw
        ${lib.concatMapStrings (id: ''
          cp -a ${pkgs.openclawRuntimePlugins.${id}} $root/dist/extensions/${id}
          chmod -R u+w $root/dist/extensions/${id}
          # OpenClaw's resolver fast path loads every relative .js import under
          # dist/ as ESM, which breaks CommonJS deps (e.g. discord-api-types).
          # Keep them outside dist/ behind a symlink; Node resolves modules by
          # real path, so they take the default resolver.
          mkdir -p $root/plugin-deps/${id}
          mv $root/dist/extensions/${id}/node_modules $root/plugin-deps/${id}/node_modules
          ln -s ../../../plugin-deps/${id}/node_modules $root/dist/extensions/${id}/node_modules
          # The plugin's openclaw peer dep links to the original gateway; point
          # it at this copy so the plugin shares the gateway's SDK instance.
          ln -sfn $out/lib/openclaw $root/plugin-deps/${id}/node_modules/openclaw
        '') bundledPlugins}
        substituteInPlace $out/bin/openclaw --replace-fail ${pkgs.openclaw-gateway} $out
      '';

  # The batteries bundle (tools on PATH), built on the gateway above that
  # bundles the plugins; hence no runtimePlugins.
  package = pkgs.openclaw.override { openclaw-gateway = gatewayWithPlugins; };

  # The bundle's tools gathered into one profile, which the Codex runtime finds
  # in its per-agent home (linked by prepareState below).
  toolsProfile = pkgs.symlinkJoin {
    name = "openclaw-tools";
    paths = map builtins.dirOf (lib.splitString ":" package.OPENCLAW_TOOLS_PATH);
  };

  # Nix-managed workspace bootstrap files. OpenClaw needs all five, and they
  # are replaced on every gateway start (USER.md included), so learned facts
  # belong in MEMORY.md / memory/.
  bootstrapFiles = {
    "AGENTS.md" = ./openclaw-workspace/AGENTS.md;
    # Tsume, the head-maid persona.
    "SOUL.md" = ./openclaw-workspace/SOUL.md;
    "TOOLS.md" = ./openclaw-workspace/TOOLS.md;
    "IDENTITY.md" = ./openclaw-workspace/IDENTITY.md;
    "USER.md" = ./openclaw-workspace/USER.md;
  };

  # Runs as `user` before each gateway start, doing what the Home Manager
  # module did at activation.
  prepareState = pkgs.writeShellScript "openclaw-prepare-state" ''
    set -eu
    install -d -m 0700 ${workspaceDir}
    ${lib.concatStrings (
      lib.mapAttrsToList (name: src: ''
        install -m 0644 ${src} ${workspaceDir}/${name}
      '') bootstrapFiles
    )}
    profile=${stateDir}/agents/main/agent/codex-home/home/.nix-profile
    mkdir -p "$profile"
    ln -sfn ${toolsProfile}/bin "$profile/bin"
  '';
in
{
  sops.secrets."discord_secrets/discord_bot_token" = { };
  # Numeric Discord user ID; not a credential, just kept out of the repo.
  sops.secrets."discord_secrets/discord_allowed_user_id" = { };
  sops.secrets."openclaw/gateway_token" = { };

  # OpenClaw loads ~/.openclaw/.env itself, in both the gateway and the CLI,
  # so the secrets reach `openclaw status` etc. without a wrapper. Rendered at
  # activation, so they never land in the world-readable Nix store. There is
  # deliberately no OPENAI_API_KEY: the model uses only the ChatGPT sign-in
  # (`openclaw models auth login --provider openai --device-code`, kept in the
  # state dir), with no API key to fall back on.
  sops.templates."openclaw.env" = {
    owner = "user";
    path = "${stateDir}/.env";
    content = ''
      DISCORD_BOT_TOKEN=${config.sops.placeholder."discord_secrets/discord_bot_token"}
      DISCORD_ALLOWED_USER=${config.sops.placeholder."discord_secrets/discord_allowed_user_id"}
      OPENCLAW_GATEWAY_TOKEN=${config.sops.placeholder."openclaw/gateway_token"}
    '';
  };

  # sops-nix would otherwise create ~/.openclaw as root for the .env link,
  # leaving the gateway unable to write the rest of the state dir.
  system.activationScripts.openclawStateDir = {
    deps = [ "users" ];
    text = ''
      install -d -m 0700 -o user -g ${config.users.users.user.group} ${stateDir}
    '';
  };
  system.activationScripts.setupSecrets.deps = [ "openclawStateDir" ];

  # The CLI, run as `user`, uses the service's config (the state dir is its
  # default ~/.openclaw already), in Nix mode like the gateway.
  environment.systemPackages = [ package ];
  environment.variables = {
    OPENCLAW_CONFIG_PATH = config.services.openclaw-gateway.configPath;
    OPENCLAW_NIX_MODE = "1";
  };

  services.openclaw-gateway = {
    enable = true;
    inherit package stateDir;
    user = "user";
    group = config.users.users.user.group;
    createUser = false;
    # Nix mode: OpenClaw treats its config as immutable.
    environment.OPENCLAW_NIX_MODE = "1";
    execStartPre = [ "${prepareState}" ];

    config = {
      gateway = {
        mode = "local";
        bind = "loopback";
        # Loopback-only and not reverse-proxied. A shared token is still
        # required: without it, local clients lacking a paired device
        # identity (e.g. the `openclaw gateway status` probe) are rejected.
        auth = {
          mode = "token";
          token = "\${OPENCLAW_GATEWAY_TOKEN}";
        };
      };

      # The implicit main agent, made explicit as the Home Manager module did.
      agents.entries.main = { };
      agents.defaults = {
        workspace = workspaceDir;
        # The bootstrap files are Nix-managed (prepareState above), so
        # OpenClaw must not seed its own.
        skipBootstrap = true;
        model.primary = "openai/gpt-6-sol";
        # Run turns on the Codex app-server harness, failing closed instead
        # of falling back to the embedded runtime.
        models."openai/gpt-6-sol".agentRuntime.id = "codex";
      };

      plugins.entries = lib.genAttrs bundledPlugins (_: {
        enabled = true;
      });

      channels.discord = {
        enabled = true;
        token = {
          source = "env";
          provider = "default";
          id = "DISCORD_BOT_TOKEN";
        };
        dmPolicy = "allowlist";
        allowFrom = [ "\${DISCORD_ALLOWED_USER}" ];
        # Servers are allowlisted: only the listed guild, and within it only
        # the listed channel (a channels map is itself an allowlist). Answers
        # the same allowlisted user as DMs, without needing a mention.
        groupPolicy = "allowlist";
        guilds."1556544589836329000" = {
          requireMention = false;
          users = [ "\${DISCORD_ALLOWED_USER}" ];
          channels."1556544594735530016".enabled = true;
        };
      };
    };
  };

  systemd.services.openclaw-gateway = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      # Log to the journal instead of the module's log file.
      StandardOutput = lib.mkForce "journal";
      StandardError = lib.mkForce "journal";
      RestartSec = lib.mkForce 5;
      # Lets the gateway drain active turns before its children are killed.
      TimeoutStopSec = 330;
      KillMode = "mixed";
    };
  };
}
