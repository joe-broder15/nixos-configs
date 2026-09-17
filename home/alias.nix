{ ... }:

{
  programs.zsh.shellAliases = {
    # Sort by mtime, most recent last, so newest files stay visible at the bottom.
    ll = "ls -lhrt";
    gs = "git status";
    # List only the aliases managed by this file.
    # NOTE: this string is hand-written, not generated from the aliases below;
    # update it manually whenever an alias here is added, removed, or renamed.
    help = "printf '%s\\n' 'Available aliases:' '  gs                Show Git status' '  help              Show this alias list' '  hmp               Pull and reload Home Manager' '  hmr               Reload Home Manager' '  home              Go to the home directory' '  host-age-pubkey   Print the host AGE public key' '  jfu               journalctl -f -u (follow a units logs)' '  ll                List files by modification time' '  syno              Go to the Synology share' '  update-sops-keys  Update SOPS recipients' '  user-age-pubkey   Print your personal sops AGE public key' '  wg-start          Start the wg0 WireGuard service' '  wg-stop           Stop the wg0 WireGuard service'";
    # Derive the AGE public key sops-nix uses for this host, per configurations/common/crypto.nix.
    "host-age-pubkey" = "nix run nixpkgs#ssh-to-age -- -i /etc/ssh/ssh_host_ed25519_key.pub";
    # Print your personal sops-nix admin AGE public key, from its recorded comment in the age keys file.
    "user-age-pubkey" = "sed -n 's/^# public key: //p' ~/.config/sops/age/keys.txt";
    "update-sops-keys" = "sops updatekeys secrets/common.yaml";
    # Reload the zircon Home Manager config from this repo's flake.
    hmr = "home-manager switch --flake ~/nixos-configs#zircon";
    # Pull latest changes first, then reload.
    hmp = "git -C ~/nixos-configs pull && home-manager switch --flake ~/nixos-configs#zircon";
    # Jump to the home directory.
    home = "cd ~";
    # Jump to the Synology CIFS share.
    syno = "cd /mnt/Library1";
    # Follow a systemd unit's logs, e.g. `jfu wg-quick-wg0`.
    jfu = "journalctl -f -u";
    # Start/stop the wg0 WireGuard client service.
    wg-start = "sudo systemctl start wg-quick-wg0";
    wg-stop = "sudo systemctl stop wg-quick-wg0";
  };
}
