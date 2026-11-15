# Shared base domain for the homelab reverse proxy (proxy.nix) and dashboard
# (homer.nix).
{ ... }:
{
  # "local." subdomain keeps this apart from the public "ddns." domain used by
  # common/namecheap-ddns-updater.nix, avoiding wildcard-cert/DNS conflicts.
  _module.args.baseDomain = "local.clubtropicalexcellent.vip";
}
