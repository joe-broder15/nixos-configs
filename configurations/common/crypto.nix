{ ... }:

{
  services.openssh = {
    generateHostKeys = true;
    # Only this key is generated (not the usual rsa+ed25519 pair), since it
    # doubles as the host's sops-nix Age identity below.
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };

  # Single encrypted secrets file shared by both hosts; per-secret access is
  # controlled by which hosts' Age keys .sops.yaml lists as recipients.
  sops.defaultSopsFile = ../../secrets/common.yaml;
  # sops-nix derives this host's Age decryption key from its SSH host key, so
  # no separate Age key needs to be provisioned per host.
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
}
