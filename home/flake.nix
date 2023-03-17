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
        "user@nixmsi" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages."x86_64-linux";
          modules = [
            notlua.nixosModules.x86_64-linux.default
            nur.nixosModules.nur
            { nixpkgs.overlays = [
              nix-gaming.overlays.default
              (self: super: {
                clang_latest = super.clang_15;
                clang-tools_latest = super.clang-tools_15;
              })
            ]; }
            ./hosts/nixmsi.nix
            (getPriv "nixmsi")
          ];
        };
      };
    };
}
