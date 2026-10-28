{ ... }:
{
  # ".local" here is just a naming convenience, not real mDNS resolution (LAN devices don't advertise via
  # avahi/mDNS); IPs are static DHCP reservations pinned by hand, same pattern as synology.local in common/synology.nix.
  networking.hosts = {
    "192.168.1.100" = [ "proxmox.local" ];
    "192.168.1.101" = [ "homelab.local" ];
  };
}
