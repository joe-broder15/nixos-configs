{ ... }:

{
  # Theme lives in tui.json (not opencode.json) for current opencode releases.
  programs.opencode = {
    enable = true;
    settings.model = "xai/grok-4.7";
    tui.theme = "dracula";
  };
}
