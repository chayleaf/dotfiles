{
  description = "Home Manager configuration of chayleaf";

  inputs = {
    #nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    #instead take it from system config
    nur.url = "github:nix-community/NUR";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, nur }:
    let
      priv = import ./private.nix inputs;
    in {
      homeConfigurations = {
        "user@nixmsi" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages."x86_64-linux";
          modules = [
            nur.nixosModules.nur
            ./hosts/nixmsi.nix
            # IRL-related private config
            priv.nixmsi
          ];
        };
      };
    };
}
