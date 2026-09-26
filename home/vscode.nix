{ pkgs, ... }:

{
  # Match the terminal font configured for Terminator (see zircon.nix).
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
      # Same quoting rule as the terminal font above.
      "editor.fontFamily" = "'GohuFont 14 Nerd Font Mono'";
      # GohuFont is a bitmap font; point size must be 11 or 14.
      "editor.fontSize" = 14;
      # Must match the "label" in the dracula-theme extension's package.json,
      # not just "Dracula".
      "workbench.colorTheme" = "Dracula Theme";
    };
    profiles.default.extensions = with pkgs.vscode-extensions; [
      rust-lang.rust-analyzer
      golang.go
      jnoortheen.nix-ide
      ms-python.python
      usernamehw.errorlens
      eamodio.gitlens
      johnpapa.vscode-peacock
      dracula-theme.theme-dracula
    ];
  };
}
