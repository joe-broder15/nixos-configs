{ pkgs, lib, ... }:

let
  # Not packaged in nixpkgs. Pin gpakosz/.tmux in the store so ~/.tmux.conf
  # can symlink at it; activation does not clone the repo into $HOME.
  oh-my-tmux = pkgs.fetchFromGitHub {
    owner = "gpakosz";
    repo = ".tmux";
    rev = "58a3dcc0d718ec0fa1c0d5a2fddd640a1ad7a5b7"; # 2026-08-08
    hash = "sha256-YDzbZVFhrAMBhOI8HVDxR3rEPkrEwG57IUbnZicmfn4=";
  };
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

  # Upstream install: ~/.tmux.conf is a symlink to the repo's .tmux.conf.
  # That file says not to edit it; overrides belong in ~/.tmux.conf.local.
  home.file.".tmux.conf".source = "${oh-my-tmux}/.tmux.conf";

  # Upstream copies .tmux.conf.local (tmux sources it as $TMUX_CONF.local, and
  # prefix+e opens it). The store copy is mode 0444, so seed a writable file
  # once and leave any existing override file alone.
  home.activation.installOhMyTmuxLocal = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    local_conf="$HOME/.tmux.conf.local"
    if [ ! -e "$local_conf" ] && [ ! -L "$local_conf" ]; then
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 644 ${oh-my-tmux}/.tmux.conf.local "$local_conf"
    fi
  '';
}
