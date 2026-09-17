# Shared base domain for the homelab reverse proxy (proxy.nix) and dashboard
# (homer.nix), injected as a module argument so both stay in sync.
{ ... }:
{
  # "local." subdomain keeps this apart from the public "ddns." domain used by
  # common/namecheap-ddns-updater.nix, avoiding wildcard-cert/DNS conflicts.
  _module.args.baseDomain = "local.clubtropicalexcellent.vip";
}
