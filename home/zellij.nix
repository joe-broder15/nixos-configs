{ pkgs, lib, ... }:

let
  # Not packaged in nixpkgs; pin the upstream release wasm instead.
  fetchPluginWasm =
    {
      pname,
      version,
      url,
      hash,
    }:
    pkgs.stdenvNoCC.mkDerivation {
      inherit pname version;
      src = pkgs.fetchurl { inherit url hash; };
      dontUnpack = true;
      installPhase = "cp $src $out";
    };

  zjstatus-hints = fetchPluginWasm rec {
    pname = "zjstatus-hints";
    version = "0.1.4";
    url = "https://github.com/b0o/zjstatus-hints/releases/download/v${version}/zjstatus-hints.wasm";
    hash = "sha256-k2xV6QJcDtvUNCE4PvwVG9/ceOkk+Wa/6efGgr7IcZ0=";
  };

  # Tab bar that shows each tab's Claude Code activity.
  zellaude = fetchPluginWasm rec {
    pname = "zellaude";
    version = "0.5.1";
    url = "https://github.com/ishefi/zellaude/releases/download/v${version}/zellaude.wasm";
    hash = "sha256-63Ss3skvmN/m4XwAXBwY29cR1v3G8KMU3n5EUr9PF/k=";
  };

  # Permissions each plugin requests, pre-granted below.
  pluginPermissions = {
    zjstatus-hints = [
      "ReadApplicationState"
      "MessageAndLaunchOtherPlugins"
    ];
    zellaude = [
      "ReadApplicationState"
      "ChangeApplicationState"
      "RunCommands"
      "ReadCliPipes"
      "MessageAndLaunchOtherPlugins"
    ];
  };
in
{
  # zellaude's Claude Code hook script shells out to jq.
  home.packages = [ pkgs.jq ];

  # zjstatus-hints runs as a background plugin with no pane, so zellij can never show
  # its permission prompt and it silently stays unauthorized; zellaude would otherwise
  # prompt inside its cramped 1-line bar. Pre-grant both in zellij's permission cache;
  # appended (not symlinked) since zellij writes other grants there.
  home.activation.grantZellijPluginPermissions = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    ''
      PERMS="''${XDG_CACHE_HOME:-$HOME/.cache}/zellij/permissions.kdl"
      $DRY_RUN_CMD mkdir -p "$(dirname "$PERMS")"
    ''
    + lib.concatStrings (
      lib.mapAttrsToList (name: perms: ''
        PLUGIN="$HOME/.config/zellij/plugins/${name}.wasm"
        if ! grep -qF "\"$PLUGIN\"" "$PERMS" 2>/dev/null; then
          printf '"%s" {\n${lib.concatMapStrings (p: "    ${p}\\n") perms}}\n' "$PLUGIN" \
            | $DRY_RUN_CMD tee -a "$PERMS" > /dev/null
        fi
      '') pluginPermissions
    )
  );

  # Integration would auto-launch zellij in every new zsh; start it manually instead.
  programs.zellij = {
    enable = true;
    enableZshIntegration = false;
    # Symlinked to ~/.config/zellij/plugins and aliased by name for use in layouts.
    plugins = [
      pkgs.zellijPlugins.zjstatus
      zjstatus-hints
      zellaude
    ];
    settings = {
      # The module auto-loads every plugin at startup; only zjstatus-hints needs that,
      # zjstatus and zellaude belong in the layout's bar panes, not as background plugins.
      load_plugins = lib.mkForce { _children = [ { zjstatus-hints = [ ]; } ]; };
      theme = "dracula";
      pane_frames = true;
      # Default "titles" only draws a title bar above each pane.
      pane_frame_style = "full";
      # Skip the "tip of the day" popup on launch.
      show_startup_tips = false;
    };

    # Replaces zellij's built-in tab-bar + status-bar: zellaude tabs (with per-tab Claude
    # Code activity, session name and mode) on top, a zjstatus bar of context-aware
    # keybinding hints on the bottom. {pipe_zjstatus_hints} is fed by zjstatus-hints over
    # its default pipe name. On first load zellaude writes its hook script next to its
    # wasm and registers it in ~/.claude/settings.json.
    layouts.default =
      let
        # A one-line borderless pane running the given plugin.
        bar = location: pluginConfig: {
          pane = {
            _props = {
              size = 1;
              borderless = true;
            };
            plugin = {
              _props.location = location;
            }
            // pluginConfig;
          };
        };
      in
      {
        layout.default_tab_template._children = [
          (bar "zellaude" { })
          { children = { }; }
          (bar "zjstatus" {
            format_left = "{pipe_zjstatus_hints}";
            format_space = "";

            # Required, or zjstatus won't render the pipe.
            pipe_zjstatus_hints_format = "{output}";
          })
        ];
      };
  };
}
