{
  description = "NixOS multi-host configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, home-manager, ... }:
    let
      # Helper function to create a NixOS configuration with Home Manager
      mkHost = { hostname, system, modules ? [], homeModules ? [] }: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit self; };
        modules = [
          # Base modules
          ./modules/base.nix
          
          # Home Manager
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.stanmart = { ... }: {
              imports = [
                ./home/stanmart/common.nix
              ] ++ homeModules;
            };
          }
        ] ++ modules;
      };
    in
    {
      nixosConfigurations = {
        # Hetzner cloud server (x86_64)
        hetzner-cloud = mkHost {
          hostname = "hetzner-cloud";
          system = "x86_64-linux";
          modules = [
            disko.nixosModules.disko
            ./hosts/hetzner-cloud/default.nix
          ];
          homeModules = [
            ./home/stanmart/simple-shell.nix
          ];
        };

        # Raspberry Pi with Pi-hole (aarch64)
        raspi-pihole = mkHost {
          hostname = "raspi-pihole";
          system = "aarch64-linux";
          modules = [
            ./hosts/raspi-pihole/default.nix
          ];
          homeModules = [
            ./home/stanmart/fancy-shell.nix
          ];
        };

        # Desktop machine (x86_64)
        desktop = mkHost {
          hostname = "desktop";
          system = "x86_64-linux";
          modules = [
            ./hosts/desktop/default.nix
          ];
          homeModules = [
            ./home/stanmart/desktop.nix
            ./home/stanmart/fancy-shell.nix
          ];
        };

        # OrbStack VM (aarch64)
        # Note: Doesn't use mkHost because it imports OrbStack's own configs
        orbstack = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = { inherit self; };
          modules = [
            ./hosts/orbstack/default.nix
            
            # Home Manager
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.stanmart = { ... }: {
                imports = [
                  ./home/stanmart/common.nix
                  ./home/stanmart/fancy-shell.nix
                ];
              };
            }
          ];
        };
      };
    };
}
