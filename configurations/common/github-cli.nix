{ config, ... }:

{
  sops.secrets."github_secrets/gh_token" = { };

  # gh treats ~/.config/gh/hosts.yml as its login store, so a rendered PAT
  # authenticates every invocation without `gh auth login` or an env var.
  # Written at activation so the token never enters the Nix store. A PAT does
  # not refresh, so gh will not rewrite this file out from under sops-nix.
  sops.templates."gh-hosts.yml" = {
    owner = config.users.users.zircon.name;
    mode = "0400";
    path = "${config.users.users.zircon.home}/.config/gh/hosts.yml";
    content = ''
      github.com:
          git_protocol: https
          oauth_token: ${config.sops.placeholder."github_secrets/gh_token"}
          user: joe-broder15
          users:
              joe-broder15:
                  oauth_token: ${config.sops.placeholder."github_secrets/gh_token"}
    '';
  };

  # sops-nix would otherwise create ~/.config/gh as root.
  system.activationScripts.ghConfigDir = {
    deps = [ "users" ];
    text = ''
      install -d -m 0700 -o ${config.users.users.zircon.name} -g ${config.users.users.zircon.group} ${config.users.users.zircon.home}/.config/gh
    '';
  };
  system.activationScripts.setupSecrets.deps = [ "ghConfigDir" ];
}
