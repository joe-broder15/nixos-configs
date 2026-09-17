{ pkgs, lib, ... }:

{
  imports = [
    ./shell.nix
    ./gtk.nix
    ./alias.nix
  ];

  # Set explicitly (not mkDefault) so standalone `home-manager switch --flake .#zircon`
  # works; the thinkpad NixOS module sets the same values via mkDefault to avoid conflict.
  home.username = "zircon";
  home.homeDirectory = "/home/zircon";

  # Do not change; tracks the Home Manager release this config was written for.
  home.stateVersion = "24.11";

  home.packages = with pkgs; [
    spotify
    tmux
    brave
    terminator
    nerd-fonts.gohufont
    discord
    signal-desktop
    protonmail-desktop
    proton-vpn
    keepassxc
    claude-code
    codex
    gh
    gnomeExtensions.dash-to-panel
    tree
    fastfetch
    gparted
    htop
    solaar
  ];

  home.file = {
    # GohuFont is a bitmap font; point size must be 11 or 14.
    ".config/terminator/config".text = ''
      [global_config]
      [keybindings]
      [profiles]
        [[default]]
          use_system_font = False
          font = GohuFont 11 Nerd Font Mono 11
      [layouts]
        [[default]]
          [[[window0]]]
            type = Window
            parent = ""
          [[[child1]]]
            type = Terminal
            parent = window0
      [plugins]
    '';
  };

  # GNOME extensions installed via home.packages must be explicitly enabled by UUID.
  # Dash to Panel reads its pinned/favorite apps from the same favorite-apps key
  # GNOME Shell's default dash uses, rather than a separate setting of its own.
  dconf.settings."org/gnome/shell" = {
    enabled-extensions = [
      pkgs.gnomeExtensions.dash-to-panel.extensionUuid
    ];
    favorite-apps = [
      "brave-browser.desktop"
      "kitty.desktop"
      "code.desktop"
      "org.gnome.Nautilus.desktop"
      "discord.desktop"
      "proton-mail.desktop"
      "signal.desktop"
      "org.keepassxc.KeePassXC.desktop"
      "steam.desktop"
    ];
  };

  # Match the terminal font configured for Terminator (see home.file above).
  # terminal.integrated.fontFamily is parsed as CSS font-family, where an
  # unquoted identifier can't contain whitespace or digits; since the family
  # name here has both, it must be single-quoted or VS Code silently falls
  # back to its default terminal font instead of erroring.
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    profiles.default.userSettings = {
      "terminal.integrated.fontFamily" = "'GohuFont 11 Nerd Font Mono'";
      "terminal.integrated.fontSize" = 12;
    };
    profiles.default.extensions = with pkgs.vscode-extensions; [
      rust-lang.rust-analyzer
      golang.go
      jnoortheen.nix-ide
      ms-python.python
      usernamehw.errorlens
      eamodio.gitlens
      johnpapa.vscode-peacock
    ];
  };

  programs.git = {
    enable = true;
    settings.user = {
      name = "joe-broder15";
      email = "joe.broder@proton.me";
    };
  };

  programs.home-manager.enable = true;

  # GohuFont is a bitmap font; point size must be 11 or 14.
  programs.kitty = {
    enable = true;
    settings = {
      font_family = "GohuFont 11 Nerd Font Mono";
      font_size = 11;
      tab_bar_style = "powerline";
      tab_powerline_style = "angled";
      cursor_shape = "beam";
      # "splits" first so new tabs start in split mode; the rest stay available via next_layout.
      enabled_layouts = "splits,tall,fat,grid,stack";
      # Digits only (instead of kitty's default letter+digit mix) for the focus_visible_window overlay below.
      visual_window_select_characters = "1234567890";
      # Draw a full border around every pane instead of just the shared edge between them.
      draw_minimal_borders = "no";
      window_margin_width = "2";
      window_border_width = "1pt";
    };
    # Pane splitting/navigation for kitty's own "splits" layout; works regardless of
    # window manager since it's kitty dividing its own OS window, not OS-level tiling.
    keybindings = {
      "ctrl+shift+enter" = "launch --location=hsplit --cwd=current";
      "ctrl+shift+backslash" = "launch --location=vsplit --cwd=current";
      "ctrl+shift+h" = "neighboring_window left";
      "ctrl+shift+l" = "neighboring_window right";
      "ctrl+shift+k" = "neighboring_window up";
      "ctrl+shift+j" = "neighboring_window down";
      "ctrl+shift+r" = "start_resizing_window";
      # Overlays a number on every pane in the tab; press it to jump focus there.
      "ctrl+shift+p" = "focus_visible_window";
    };
  };

  # Bootstrap a personal sops-nix admin AGE key on first activation, mirroring
  # how configurations/common/crypto.nix auto-generates the host SSH key.
  home.activation.generateSopsAgeKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    KEY_FILE="$HOME/.config/sops/age/keys.txt"
    if [ ! -f "$KEY_FILE" ]; then
      # $DRY_RUN_CMD is a Home Manager convention: it no-ops under `--dry-run`.
      $DRY_RUN_CMD mkdir -p "$(dirname "$KEY_FILE")"
      # Full store path since activation scripts run with a minimal PATH.
      $DRY_RUN_CMD ${pkgs.age}/bin/age-keygen -o "$KEY_FILE"
      $DRY_RUN_CMD chmod 600 "$KEY_FILE"
    fi
  '';
}
