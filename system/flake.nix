{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    utils.url = "github:gytis-ivaskevicius/flake-utils-plus";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    impermanence.url = "github:nix-community/impermanence";
    # simply make rust-overlay available for the whole system
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-gaming = {
      url = "github:fufexan/nix-gaming";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-22_11.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, utils, nixos-hardware, impermanence, nix-gaming, nixos-mailserver, ... }:
  let
    # IRL-related stuff I'd rather not put into git
    priv =
      if builtins.pathExists ./private.nix then (import ./private.nix)
      else if builtins.pathExists ./private/default.nix then (import ./private)
      else { };
    getPriv = hostname: with builtins; if hasAttr hostname priv then getAttr hostname priv else { };
    common = hostname: [ (getPriv hostname) ];
    lib = nixpkgs.lib // {
      quoteListenAddr = addr:
        if nixpkgs.lib.hasInfix ":" addr then "[${addr}]" else addr;
    };
    mkHost = args @ { system ? "x86_64-linux", modules, ... }: {
      inherit system;
      extraArgs = {
        inherit nixpkgs;
      };
      specialArgs = {
        inherit lib;
        hardware = nixos-hardware.nixosModules;
      };
    } // args;
  in utils.lib.mkFlake {
    inherit self inputs;
    hostDefaults.modules = [
      ./modules/vfio.nix
      ./modules/ccache.nix
      ./modules/impermanence.nix
      ./modules/common.nix
      impermanence.nixosModule 
    ];
    hosts = builtins.mapAttrs (_: mkHost) {
      nixmsi = {
        modules = [
          nix-gaming.nixosModules.pipewireLowLatency
          ./hardware/msi_delta_15.nix
          ./hosts/nixmsi.nix
        ] ++ common "nixmsi";
      };
      nixserver = {
        modules = [
          nixos-mailserver.nixosModules.default
          ./hardware/hp_probook_g0.nix
          ./hosts/nixserver
        ] ++ common "nixserver";
      };
      router = {
        system = "aarch64-linux";
        modules = [
          ./hardware/bpi_r3.nix
          ./hosts/router
        ];
      };
    };
  };
}
