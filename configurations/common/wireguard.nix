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

  sops.secrets.${secretKey} = { };

  networking = {
    wg-quick.interfaces.wg0.configFile = config.sops.secrets.${secretKey}.path;
  }
  // lib.optionalAttrs (natExternalInterface != null) {
    nat = {
      enable = true;
      enableIPv6 = true;
      externalInterface = natExternalInterface;
      internalInterfaces = [ "wg0" ];
    };
  };
}
