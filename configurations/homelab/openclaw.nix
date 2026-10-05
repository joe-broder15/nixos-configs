# OpenClaw gateway, via nix-openclaw's official NixOS module
# (services.openclaw-gateway, imported in flake.nix). The model is reached
# through the OpenAI API, and the gateway talks to Discord, answering only one
# allowlisted user; all credentials are held in sops.
{ config, openclawPackages, ... }:

let
  # Discord is an external runtime plugin, not part of the gateway. The NixOS
  # module has no runtimePlugins option (only the Home Manager one does), so
  # load the prebuilt plugin the same way that option would.
  discordPlugin = openclawPackages.openclaw-runtime-plugin-discord;
in
{
  sops.secrets."llm_providers/openai_key" = { };
  sops.secrets."discord_secrets/discord_bot_token" = { };
  # Numeric Discord user ID; not a credential, just kept out of the repo.
  sops.secrets."discord_secrets/discord_allowed_user_id" = { };

  # Rendered at activation so secrets never land in the world-readable Nix
  # store; ${VAR} strings in the config below are substituted from it.
  sops.templates."openclaw.env" = {
    restartUnits = [ "openclaw-gateway.service" ];
    content = ''
      OPENAI_API_KEY=${config.sops.placeholder."llm_providers/openai_key"}
      DISCORD_BOT_TOKEN=${config.sops.placeholder."discord_secrets/discord_bot_token"}
      DISCORD_ALLOWED_USER=${config.sops.placeholder."discord_secrets/discord_allowed_user_id"}
    '';
  };

  services.openclaw-gateway = {
    enable = true;
    package = openclawPackages.openclaw;
    environmentFiles = [ config.sops.templates."openclaw.env".path ];
    environment = {
      # Set by the Home Manager module but not the NixOS one: the config is
      # immutable, so setup/onboarding/self-update flows refuse to rewrite it.
      OPENCLAW_NIX_MODE = "1";
      # Plugins come only from plugins.load.paths below.
      OPENCLAW_DISABLE_PERSISTED_PLUGIN_REGISTRY = "1";
      # This unit owns the lifecycle; keep doctor from installing its own.
      OPENCLAW_SERVICE_REPAIR_POLICY = "external";
    };

    config = {
      gateway = {
        mode = "local";
        bind = "loopback";
        # Loopback-only and not reverse-proxied; Discord (an outbound
        # connection) is the only way in from outside the host.
        auth.mode = "none";
      };

      agents.defaults = {
        model.primary = "openai/gpt-6-sol";
        # Without an explicit runtime, OpenAI models may be routed to the Codex
        # app-server harness (a separate plugin wanting a ChatGPT login); the
        # embedded runtime uses OPENAI_API_KEY directly.
        models."openai/gpt-6-sol".agentRuntime.id = "openclaw";
      };

      plugins = {
        load.paths = [ "${discordPlugin}" ];
        entries.discord.enabled = true;
      };

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
}
