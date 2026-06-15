{
  description = "NixOS homelab configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
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
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.zircon = import ./home/zircon.nix;
          }
        ];
      };

      # Standalone Home Manager configuration. Usable on any machine with Nix
      # (not just NixOS) via:
      #   nix run home-manager/master -- switch --flake .#zircon
      #   home-manager switch --flake .#zircon
      homeConfigurations."zircon" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home/zircon.nix ];
      };

      formatter.${system} = pkgs.nixfmt;
    };
}
