{
  pkgs,
  lib,
  chatgptDesktop,
  ...
}:

{
  imports = [
    ./shell.nix
    ./gtk.nix
    ./alias.nix
    ./kitty.nix
    ./terminator.nix
    ./vscode.nix
    ./zellij.nix
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
    nerd-fonts.gohufont
    discord
    signal-desktop
    protonmail-desktop
    proton-vpn
    keepassxc
    claude-code
    codex
    chatgptDesktop
    gh
    gnomeExtensions.dash-to-panel
    tree
    fastfetch
    gparted
    htop
    solaar
    emacs
  ];

  # GNOME extensions installed via home.packages must be explicitly enabled by UUID.
  # Dash to Panel reads its pinned/favorite apps from the same favorite-apps key
  # GNOME Shell's default dash uses, rather than a separate setting of its own.
  dconf.settings."org/gnome/shell" = {
    enabled-extensions = [
      pkgs.gnomeExtensions.dash-to-panel.extensionUuid
    ];
    favorite-apps = [
      "brave-browser.desktop"
      "Alacritty.desktop"
      "code.desktop"
      "org.gnome.Nautilus.desktop"
      "discord.desktop"
      "proton-mail.desktop"
      "signal.desktop"
      "org.keepassxc.KeePassXC.desktop"
      "steam.desktop"
    ];
  };

  programs.git = {
    enable = true;
    settings.user = {
      name = "joe-broder15";
      email = "joe.broder@proton.me";
    };
  };

  # Same font as kitty.nix; GohuFont is a bitmap font, so size must be 11 or 14.
  programs.alacritty = {
    enable = true;
    theme = "dracula";
    settings.font = {
      normal.family = "GohuFont 11 Nerd Font Mono";
      size = 11;
    };
  };

  programs.home-manager.enable = true;

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

  # Clone spacemacs on first activation only; never touches an existing
  # ~/.emacs.d so it won't clobber local edits or block re-activation.
  home.activation.installSpacemacs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    EMACS_DIR="$HOME/.emacs.d"
    if [ ! -d "$EMACS_DIR" ]; then
      $DRY_RUN_CMD ${pkgs.git}/bin/git clone -b develop https://github.com/syl20bnr/spacemacs "$EMACS_DIR"
    fi
  '';
}
