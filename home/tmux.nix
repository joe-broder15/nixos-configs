{ pkgs, ... }:

let
  # Not packaged in nixpkgs. Pin gpakosz/.tmux in the store so ~/.tmux.conf
  # can symlink at it; activation does not clone the repo into $HOME.
  oh-my-tmux = pkgs.fetchFromGitHub {
    owner = "gpakosz";
    repo = ".tmux";
    rev = "58a3dcc0d718ec0fa1c0d5a2fddd640a1ad7a5b7"; # 2026-08-08
    hash = "sha256-YDzbZVFhrAMBhOI8HVDxR3rEPkrEwG57IUbnZicmfn4=";
  };

  # Same sample upstream ships, with mouse mode enabled. The build fails if
  # that line moves, so a pin bump cannot silently drop the override.
  tmuxConfLocal = pkgs.runCommand "tmux.conf.local" { } ''
    sed 's/^#set -g mouse on$/set -g mouse on/' \
      ${oh-my-tmux}/.tmux.conf.local > "$out"
    test "$(grep -cx 'set -g mouse on' "$out")" = 1
    test "$(grep -cx '#set -g mouse on' "$out")" = 0
  '';
in
{
  # The shell half of .tmux.conf kills the server unless perl, sed, and awk
  # are on PATH. grep is the other tool the upstream install checks for.
  home.packages = with pkgs; [
    tmux
    perl
    gawk
    gnused
    gnugrep
  ];

  # Symlink to the pinned upstream file. Do not edit it.
  home.file.".tmux.conf".source = "${oh-my-tmux}/.tmux.conf";

  # Future overrides belong in this module, not in a hand-edited home file.
  # force makes a rebuild replace an existing ~/.tmux.conf.local.
  home.file.".tmux.conf.local" = {
    source = tmuxConfLocal;
    force = true;
  };
}
