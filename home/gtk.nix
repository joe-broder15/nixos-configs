{ pkgs, ... }:
{
  gtk = {
    enable = true;

    # `name` must match the theme's on-disk directory name inside `package`;
    # GTK looks it up by string, so a mismatch here silently falls back to default.
    theme = {
      name = "Dracula";
      package = pkgs.dracula-theme;
    };

    # Vanilla Papirus, no folder recoloring.
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };

    # dracula-theme ships the cursor theme alongside the GTK theme itself
    # (share/icons/Dracula-cursors), rather than as a separate package.
    cursorTheme = {
      name = "Dracula-cursors";
      package = pkgs.dracula-theme;
      size = 32;
    };

    # Font package is installed in zircon.nix (nerd-fonts.gohufont).
    # GohuFont is a bitmap font; point size must be 11 or 14.
    font = {
      name = "GohuFont 11 Nerd Font";
      size = 11;
    };

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };

    # dracula-theme ships real gtk-4.0 assets, so GTK4 apps get the same
    # theme instead of falling back to libadwaita's default styling.
    gtk4.theme = {
      name = "Dracula";
      package = pkgs.dracula-theme;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  # GNOME reads theme names from dconf independently of the gtk.* options above;
  # keep these names in sync with theme/iconTheme/cursorTheme/font by hand.
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      gtk-theme = "Dracula";
      icon-theme = "Papirus-Dark";
      cursor-theme = "Dracula-cursors";
      color-scheme = "prefer-dark";
      font-name = "GohuFont 11 Nerd Font 11";
    };
  };
}
