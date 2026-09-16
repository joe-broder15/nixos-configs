{ pkgs, ... }:
{
  gtk = {
    enable = true;

    theme = {
      name = "gruvbox-dark";
      package = pkgs.gruvbox-dark-gtk;
    };

    iconTheme = {
      name = "oomox-gruvbox-dark";
      package = pkgs.gruvbox-dark-icons-gtk;
    };

    cursorTheme = {
      name = "Capitaine Cursors (Gruvbox)";
      package = pkgs.capitaine-cursors-themed;
      size = 32;
    };

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };

    gtk4 = {
      # gruvbox-dark-gtk ships no gtk-4.0 assets; GTK4 apps fall back to
      # libadwaita's own dark styling via gtk-application-prefer-dark-theme.
      theme = null;
      extraConfig = {
        gtk-application-prefer-dark-theme = true;
      };
    };
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      gtk-theme = "gruvbox-dark";
      icon-theme = "oomox-gruvbox-dark";
      cursor-theme = "Capitaine Cursors (Gruvbox)";
      color-scheme = "prefer-dark";
    };
  };
}
