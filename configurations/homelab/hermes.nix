# Hermes Agent (github:NousResearch/hermes-agent), run as a native systemd
# service via its NixOS module. Minimal setup: no messaging platforms, and the
# model is reached through the ChatGPT subscription via Codex OAuth, so there
# are no API keys to keep in sops. The OAuth login is a one-time manual step
# after the first deploy:
#   sudo -u hermes HERMES_HOME=/var/lib/hermes/.hermes hermes auth add openai-codex
{ ... }:

{
  services.hermes-agent = {
    enable = true;
    # Puts `hermes` on PATH with HERMES_HOME pointing at the service's state.
    addToSystemPackages = true;

    settings.model = {
      provider = "openai-codex";
      default = "gpt-5.6-sol";
    };
  };
}
