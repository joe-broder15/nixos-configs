# Hermes Agent (github:NousResearch/hermes-agent), run as a native systemd
# service via its NixOS module. Minimal setup: no messaging platforms, and the
# model is reached through the OpenAI API with a key held in sops.
{ config, ... }:

{
  sops.secrets."llm_providers/openai_key" = { };

  # Rendered at activation so the key never lands in the world-readable Nix
  # store; the module merges it into $HERMES_HOME/.env.
  sops.templates."hermes.env" = {
    restartUnits = [ "hermes-agent.service" ];
    content = ''
      OPENAI_API_KEY=${config.sops.placeholder."llm_providers/openai_key"}
    '';
  };

  services.hermes-agent = {
    enable = true;
    # Puts `hermes` on PATH with HERMES_HOME pointing at the service's state.
    addToSystemPackages = true;
    environmentFiles = [ config.sops.templates."hermes.env".path ];

    settings.model = {
      provider = "openai-api";
      default = "gpt-6-sol";
    };
  };
}
