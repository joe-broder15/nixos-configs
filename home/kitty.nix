{ ... }:

{
  # GohuFont is a bitmap font; point size must be 11 or 14.
  programs.kitty = {
    enable = true;
    themeFile = "Dracula";
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
      "ctrl+shift+space" = "command_palette";
    };
  };
}
