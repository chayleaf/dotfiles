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
    hw = nixos-hardware.nixosModules;
    # IRL-related stuff I'd rather not put into git
    priv = if builtins.pathExists ./private/default.nix then (import ./private)
           else if builtins.pathExists ./private.nix then (import ./private.nix)
           else { };
    getPriv = hostname: with builtins; if hasAttr hostname priv then getAttr hostname priv else { };
    common = hostname: [ (getPriv hostname) impermanence.nixosModule ];
    extraArgs = {
      inherit nixpkgs;
    };
  in utils.lib.mkFlake {
    inherit self inputs;
    hostDefaults.modules = [
      ./modules/vfio.nix
      ./modules/ccache.nix
      ./modules/impermanence.nix
      {
        # make this flake's nixpkgs available to the whole system
        nix = {
          generateNixPathFromInputs = true;
          generateRegistryFromInputs = true;
          linkInputs = true;
        };
        nixpkgs.overlays = [ (self: super: import ./pkgs { pkgs = super; }) ];
      }
    ];
    hosts = {
      nixmsi = {
        system = "x86_64-linux";
        modules = [
          ./hosts/nixmsi.nix
          nix-gaming.nixosModules.pipewireLowLatency
          hw.common-pc-ssd # enables fstrim
          hw.common-cpu-amd # microcode
          hw.common-cpu-amd-pstate # amd-pstate
          hw.common-gpu-amd # configures drivers
          hw.common-pc-laptop # enables tlp
        ] ++ common "nixmsi";
        inherit extraArgs;
      };
      nixserver = {
        system = "x86_64-linux";
        modules = [
          ./hosts/nixserver
          nixos-mailserver.nixosModules.default
          hw.common-pc-hdd
          hw.common-cpu-intel
        ] ++ common "nixserver";
        inherit extraArgs;
      };
    };
  };
}
