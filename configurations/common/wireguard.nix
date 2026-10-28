# Reusable wg0 client component. Each host passes its own sops secret key
# (wireguard_secrets/<host>_proton_vpn_config) and, only if it should NAT
# other traffic out through the tunnel's external interface, natExternalInterface.
{
  secretKey,
  natExternalInterface ? null,
}:
{
  config,
  lib,
  pkgs,
  ...
}:

{
  environment.systemPackages = [ pkgs.wireguard-tools ];

  # The decrypted secret is a whole wg-quick config file (private key
  # included), passed straight through as configFile below.
  sops.secrets.${secretKey} = { };

  networking = {
    wg-quick.interfaces.wg0.configFile = config.sops.secrets.${secretKey}.path;
  }
  # Only present when the caller sets natExternalInterface; enables IP
  # forwarding and masquerading so other hosts' traffic can exit via wg0.
  // lib.optionalAttrs (natExternalInterface != null) {
    nat = {
      enable = true;
      enableIPv6 = true;
      externalInterface = natExternalInterface;
      internalInterfaces = [ "wg0" ];
    };
  };
}
