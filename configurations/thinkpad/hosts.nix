{ ... }:
{
  networking.hosts = {
    "192.168.1.99" = [ "synology.local" ];
    "192.168.1.100" = [ "proxmox.local" ];
    "192.168.1.101" = [ "homelab.local" ];
  };
}
