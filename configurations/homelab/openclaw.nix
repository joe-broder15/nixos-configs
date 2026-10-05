# OpenClaw gateway, set up the way nix-openclaw's agent-first guide does it:
# its Home Manager module (programs.openclaw, wired in by flake.nix) running a
# systemd user service for `user`, with Nix-managed workspace bootstrap files.
# The model is reached through the OpenAI API, and the gateway talks to
# Discord, answering only one allowlisted user; all credentials are held in
# sops.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  homeDir = config.users.users.user.home;

  # Workaround for nix-openclaw#158 (accepted risk): loaded via runtimePlugins
  # (plugins.load.paths), the Discord plugin has no install record, so
  # OpenClaw treats it as untrusted and refuses the keyed storage it needs at
  # registration. Plugins inside the gateway package's own dist/extensions
  # count as "bundled" and are trusted, so copy the gateway and add
  # nix-openclaw's hash-pinned build of the official @openclaw/discord package
  # there. This grants that plugin trust without OpenClaw's provenance check;
  # only ever put the official package here. A full copy is needed because
  # OpenClaw resolves its package root through symlinks and rejects
  # out-of-package bundled-dir overrides. Drop this once #158 is fixed.
  gatewayWithDiscord =
    pkgs.runCommand "openclaw-gateway-with-discord-${pkgs.openclaw-gateway.version}" { }
      ''
        cp -a ${pkgs.openclaw-gateway} $out
        chmod -R u+w $out
        root=$out/lib/node_modules/openclaw
        cp -a ${pkgs.openclawRuntimePlugins.discord} $root/dist/extensions/discord
        chmod -R u+w $root/dist/extensions/discord
        # OpenClaw's resolver fast path loads every relative .js import under
        # dist/ as ESM, which breaks the plugin's CommonJS deps
        # (discord-api-types). Keep them outside dist/ behind a symlink; Node
        # resolves modules by real path, so they take the default resolver.
        mkdir -p $root/plugin-deps/discord
        mv $root/dist/extensions/discord/node_modules $root/plugin-deps/discord/node_modules
        ln -s ../../../plugin-deps/discord/node_modules $root/dist/extensions/discord/node_modules
        substituteInPlace $out/bin/openclaw --replace-fail ${pkgs.openclaw-gateway} $out
      '';
in
{
  sops.secrets."llm_providers/openai_key" = { };
  sops.secrets."discord_secrets/discord_bot_token" = { };
  # Numeric Discord user ID; not a credential, just kept out of the repo.
  sops.secrets."discord_secrets/discord_allowed_user_id" = { };
  sops.secrets."openclaw/gateway_token" = { };

  # OpenClaw loads ~/.openclaw/.env itself, in both the gateway and the CLI,
  # so the secrets reach `openclaw status` etc. without a wrapper. Rendered at
  # activation, so they never land in the world-readable Nix store.
  sops.templates."openclaw.env" = {
    owner = "user";
    path = "${homeDir}/.openclaw/.env";
    content = ''
      OPENAI_API_KEY=${config.sops.placeholder."llm_providers/openai_key"}
      DISCORD_BOT_TOKEN=${config.sops.placeholder."discord_secrets/discord_bot_token"}
      DISCORD_ALLOWED_USER=${config.sops.placeholder."discord_secrets/discord_allowed_user_id"}
      OPENCLAW_GATEWAY_TOKEN=${config.sops.placeholder."openclaw/gateway_token"}
    '';
  };

  # sops-nix would otherwise create ~/.openclaw as root for the .env link,
  # leaving Home Manager unable to write the rest of the state dir.
  system.activationScripts.openclawStateDir = {
    deps = [ "users" ];
    text = ''
      install -d -m 0700 -o user -g ${config.users.users.user.group} ${homeDir}/.openclaw
    '';
  };
  system.activationScripts.setupSecrets.deps = [ "openclawStateDir" ];

  # Start user@ at boot, so the gateway (a user service) runs without a login.
  users.users.user.linger = true;

  home-manager.users.user = {
    home.stateVersion = "24.11";

    programs.openclaw = {
      enable = true;

      workspace.bootstrapFiles = {
        agents = ./openclaw-workspace/AGENTS.md;
        # Tsubasa, the head-maid persona.
        soul = ./openclaw-workspace/SOUL.md;
        tools = ./openclaw-workspace/TOOLS.md;
        identity = ./openclaw-workspace/IDENTITY.md;
        user = ./openclaw-workspace/USER.md;
      };

      # The batteries bundle (tools on PATH), built on the gateway above that
      # bundles Discord; hence no runtimePlugins = [ "discord" ].
      package = pkgs.openclaw.override { openclaw-gateway = gatewayWithDiscord; };

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

        agents.defaults = {
          model.primary = "openai/gpt-6-sol";
          # Without an explicit runtime, OpenAI models may be routed to the
          # Codex app-server harness (a separate plugin wanting a ChatGPT
          # login); the embedded runtime uses OPENAI_API_KEY directly.
          models."openai/gpt-6-sol".agentRuntime.id = "openclaw";
        };

        plugins.entries.discord.enabled = true;

        channels.discord = {
          enabled = true;
          token = {
            source = "env";
            provider = "default";
            id = "DISCORD_BOT_TOKEN";
          };
          dmPolicy = "allowlist";
          allowFrom = [ "\${DISCORD_ALLOWED_USER}" ];
        };
      };
    };

    systemd.user.services.openclaw-gateway = {
      # The module's unit has no [Install] section, so nothing would start it
      # at boot; hook it into the (lingering) user manager's default target.
      Install.WantedBy = [ "default.target" ];

      # The rest brings the unit in line with what `openclaw gateway status`
      # checks for.
      Unit = {
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        # The module appends to /tmp/openclaw/openclaw-gateway.log (hardcoded
        # for the default instance), and that directory is gone after a reboot,
        # so the unit failed with status 209 (STDOUT). Use the journal instead.
        StandardOutput = lib.mkForce "journal";
        StandardError = lib.mkForce "journal";
        # The dirs `openclaw gateway status` expects, plus the NixOS profiles.
        Environment = [
          "PATH=/etc/profiles/per-user/user/bin:/run/current-system/sw/bin:${homeDir}/.nix-profile/bin:${homeDir}/.local/state/nix/profile/bin:/nix/profile/bin:/nix/var/nix/profiles/default/bin:${homeDir}/.local/share/pnpm/bin:${homeDir}/.local/share/pnpm:/usr/local/bin:/usr/bin:/bin"
        ];
        RestartSec = lib.mkForce "5s";
        # Lets the gateway drain active turns before its children are killed.
        TimeoutStopSec = 330;
        KillMode = "mixed";
      };
    };
  };
}
