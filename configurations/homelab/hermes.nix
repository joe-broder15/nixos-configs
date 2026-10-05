# Hermes Agent (github:NousResearch/hermes-agent), run as a native systemd
# service via its NixOS module. The model is reached through the OpenAI API,
# and the gateway talks to Discord, answering only one allowlisted user; all
# credentials are held in sops.
{ config, ... }:

{
  sops.secrets."llm_providers/openai_key" = { };
  sops.secrets."discord_secrets/discord_bot_token" = { };
  # Numeric Discord user ID; not a credential, just kept out of the repo.
  sops.secrets."discord_secrets/discord_allowed_user_id" = { };

  # Rendered at activation so secrets never land in the world-readable Nix
  # store; the module merges this into $HERMES_HOME/.env.
  sops.templates."hermes.env" = {
    restartUnits = [ "hermes-agent.service" ];
    content = ''
      OPENAI_API_KEY=${config.sops.placeholder."llm_providers/openai_key"}
      DISCORD_BOT_TOKEN=${config.sops.placeholder."discord_secrets/discord_bot_token"}
      DISCORD_ALLOWED_USERS=${config.sops.placeholder."discord_secrets/discord_allowed_user_id"}
    '';
  };

  services.hermes-agent = {
    enable = true;
    # Puts `hermes` on PATH with HERMES_HOME pointing at the service's state.
    addToSystemPackages = true;
    environmentFiles = [ config.sops.templates."hermes.env".path ];
    # Where cron output, reminders, and other proactive messages are posted.
    environment.DISCORD_HOME_CHANNEL = "1556454202060840980";

    settings.model = {
      provider = "openai-api";
      default = "gpt-6-sol";
    };

    # Transcribe Discord voice messages via OpenAI (reuses OPENAI_API_KEY);
    # the default local faster-whisper isn't in the Nix package.
    settings.stt.provider = "openai";

    # Tsubasa, the head-maid persona. Nix owns this file, so edits Hermes makes
    # to it are overwritten on rebuild.
    hermesHomeFiles."SOUL.md" = ./hermes-soul.md;

    # Channels where Hermes answers every message without an @mention.
    settings.discord.free_response_channels = [ "1556451572815241360" ];

    # Web dashboard on 127.0.0.1:9119, reverse-proxied by proxy.nix. No login
    # is configured, so anyone who can reach the vhost gets full admin access.
    backend.mode = "dashboard";
  };

  # HERMES_HOME (/var/lib/hermes/.hermes), including the .env holding the
  # secrets, is only readable by the hermes group, so the interactive CLI needs it.
  users.users.user.extraGroups = [ "hermes" ];
}
