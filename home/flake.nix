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
    nix-gaming = {
      url = "github:fufexan/nix-gaming";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    notlua = {
      url = "github:chayleaf/notlua/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nur, nix-gaming, notlua }:
    let
      # IRL-related private config
      priv = if builtins.pathExists ./private.nix then (import ./private.nix) else {};
      getPriv = (hostname: with builtins; if hasAttr hostname priv then (getAttr hostname priv) else {});
    in {
      homeConfigurations = {
        "user@nixmsi" = let system = "x86_64-linux"; in home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            binaryCachePublicKeys = [
              "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
              # "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
            ];
            binaryCaches = [
              "https://cache.nixos.org"
              # "https://nixpkgs-wayland.cachix.org"
            ];
            overlays = [
              (self: super: import ./pkgs {
                # can't use callPackage here, idk why
                pkgs = super;
                lib = super.lib;
                nur = import nur {
                  pkgs = super;
                  nurpkgs = super;
                };
              })
              nix-gaming.overlays.default
            ];
          };
          extraSpecialArgs = {
            # pkgs-wayland = nixpkgs-wayland.packages.${system};
          };
          modules = [
            notlua.nixosModules.default
            nur.nixosModules.nur
            ./hosts/nixmsi.nix
            (getPriv "nixmsi")
          ];
        };
      };
    };
}
