{
  lib,
  pkgs,
  ...
}:

{
  # Theme lives in tui.json (not opencode.json) for current opencode releases.
  programs.opencode = {
    enable = true;
    settings = {
      model = "xai/grok-4.7";
      # pkgs.opencode 1.18.31 (this nixpkgs pin) validates MCP servers directly
      # under `mcp`, not `mcp.servers`. A local server is a stdio process. The
      # command is the wrapped nixpkgs binary, so a session never calls uvx or
      # `nix run`.
      mcp.mcp-nixos = {
        type = "local";
        command = [ (lib.getExe pkgs.mcp-nixos) ];
      };
    };
    tui.theme = "dracula";
  };
}
