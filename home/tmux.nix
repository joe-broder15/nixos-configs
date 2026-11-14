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

  # Same sample upstream ships, with mouse mode on and the Powerline
  # separators (\uE0B0–\uE0B3) active. The "|" separators stay commented.
  # GohuFont Nerd Font already has those glyphs. The build fails if the
  # lines move, so a pin bump cannot silently drop the overrides.
  tmuxConfLocal = pkgs.runCommand "tmux.conf.local" { } ''
    sed \
      -e 's/^#set -g mouse on$/set -g mouse on/' \
      -e 's/^tmux_conf_theme_\(left\|right\)_separator_\(main\|sub\)=/#&/' \
      -e 's/^#\(tmux_conf_theme_\(left\|right\)_separator_\(main\|sub\)=.*\\uE0B[0-3].*\)/\1/' \
      ${oh-my-tmux}/.tmux.conf.local > "$out"
    test "$(grep -cx 'set -g mouse on' "$out")" = 1
    test "$(grep -cx '#set -g mouse on' "$out")" = 0
    for name in left_separator_main left_separator_sub right_separator_main right_separator_sub; do
      case "$name" in
        *_main) plain='""' ;;
        *) plain='"|"' ;;
      esac
      test "$(grep -cx "#tmux_conf_theme_$name=$plain" "$out")" = 1
      test "$(grep -cx "tmux_conf_theme_$name=$plain" "$out")" = 0
    done
    grep -q "^tmux_conf_theme_left_separator_main='\\\\uE0B0'" "$out"
    grep -q "^tmux_conf_theme_left_separator_sub='\\\\uE0B1'" "$out"
    grep -q "^tmux_conf_theme_right_separator_main='\\\\uE0B2'" "$out"
    grep -q "^tmux_conf_theme_right_separator_sub='\\\\uE0B3'" "$out"
    test "$(grep -c "^#tmux_conf_theme_.*separator_.*=.*\\\\uE0B" "$out")" = 0
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
