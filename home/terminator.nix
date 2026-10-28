{ ... }:

{
  # Terminator's Home Manager module renders this as ~/.config/terminator/config.
  programs.terminator = {
    enable = true;
    config = {
      global_config = { };
      keybindings = { };
      profiles.default = {
        # GohuFont is a bitmap font; point size must be 11 or 14.
        use_system_font = false;
        font = "GohuFont 11 Nerd Font Mono 11";
        cursor_shape = "ibeam";
        use_theme_colors = true;
      };
      layouts.default = {
        window0 = {
          type = "Window";
          parent = "";
        };
        child1 = {
          type = "Terminal";
          parent = "window0";
        };
      };
      plugins = { };
    };
  };
}
