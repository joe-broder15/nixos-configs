{
  description = "NixOS homelab configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      nixosConfigurations.homelab = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./machines/proxmox-vm.nix
          ./configurations/homelab/configuration.nix
        ];
      };

      nixosConfigurations.thinkpad = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./machines/thinkpad-t14.nix
          ./configurations/thinkpad/configuration.nix
        ];
      };

      formatter.${system} = pkgs.nixfmt;
    };
}
