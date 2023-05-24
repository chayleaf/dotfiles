{
  description = "NixOS + Home Manager configuration of chayleaf";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    utils.url = "github:gytis-ivaskevicius/flake-utils-plus";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    impermanence.url = "github:nix-community/impermanence";
    nur.url = "github:nix-community/NUR";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-gaming = {
      url = "github:fufexan/nix-gaming";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    notlua = {
      url = "github:chayleaf/notlua/469652092f4f2e951b0db29027b05346b32d8122";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-22_11.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, utils, nixos-hardware, impermanence, home-manager, nur, nix-gaming, notlua, nixos-mailserver, ... }:
    let
      # IRL-related stuff I'd rather not put into git
      priv =
        if builtins.pathExists ./private.nix then (import ./private.nix)
        else if builtins.pathExists ./private/default.nix then (import ./private)
        else { };
      getOr = def: s: x: with builtins; if hasAttr s x then getAttr s x else def;
      getPriv = hostname: getOr { } hostname priv;
      getPrivSys = hostname: getOr { } "system" (getPriv hostname);
      getPrivUser = hostname: user: getOr { } user (getPriv hostname);
      lib = nixpkgs.lib // {
        quoteListenAddr = addr:
          if nixpkgs.lib.hasInfix ":" addr then "[${addr}]" else addr;
      };
      config = {
        nixmsi = rec {
          system = "x86_64-linux";
          modules = [
            nix-gaming.nixosModules.pipewireLowLatency
            ./system/hardware/msi_delta_15.nix
            ./system/hosts/nixmsi.nix
          ];
          home.user = {
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
                (self: super: import ./home/pkgs {
                  # can't use callPackage here, idk why
                  pkgs = super;
                  lib = super.lib;
                  nur = import nur {
                    pkgs = super;
                    nurpkgs = super;
                  };
                  nix-gaming = nix-gaming.packages.${system};
                })
              ];
            };
            extraSpecialArgs = {
              notlua = notlua.lib.${system};
              # pkgs-wayland = nixpkgs-wayland.packages.${system};
            };
            modules = [
              nur.nixosModules.nur
              ./home/hosts/nixmsi.nix
            ];
          };
        };
        nixserver = {
          modules = [
            nixos-mailserver.nixosModules.default
            ./system/hardware/hp_probook_g0.nix
            ./system/hosts/nixserver
          ];
        };
        router = {
          system = "aarch64-linux";
          modules = [
            ./system/hardware/bpi_r3.nix
            ./system/hosts/router
          ];
        };
      };
    in utils.lib.mkFlake {
      inherit self inputs;
      hostDefaults.modules = [
        ./system/modules/vfio.nix
        ./system/modules/ccache.nix
        ./system/modules/impermanence.nix
        ./system/modules/common.nix
        impermanence.nixosModule 
      ];
      hosts = builtins.mapAttrs (hostname: args @ { system ? "x86_64-linux", modules, ... }: {
          inherit system;
          modules = modules ++ [ (getPrivSys hostname) ];
          extraArgs = {
            inherit nixpkgs;
          };
          specialArgs = {
            inherit lib;
            hardware = nixos-hardware.nixosModules;
          };
        } // (builtins.removeAttrs args [ "home" "modules" ]))
        config;
    } // {
      homeConfigurations =
        builtins.foldl'
          (a: b: a // b)
          { }
          (builtins.concatLists
            (lib.mapAttrsToList
              (hostname: config:
                lib.mapAttrsToList
                  (user: config@{ modules, ... }: {
                    "${user}@${hostname}" = home-manager.lib.homeManagerConfiguration (config // {
                      modules = config.modules ++ [ (getPrivUser hostname user) ];
                    });
                  })
                  (getOr { } "home" config))
              config));
    };
}
