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
  };

  outputs = inputs@{ self, nixpkgs, utils, nixos-hardware, rust-overlay, impermanence, nix-gaming }:
  let
    hw = nixos-hardware.nixosModules;
    # IRL-related stuff I'd rather not put into git
    priv = if builtins.pathExists ./private.nix then (import ./private.nix) else {};
    getPriv = (hostname: with builtins; if hasAttr hostname priv then getAttr hostname priv else {});
  in utils.lib.mkFlake {
    inherit self inputs;
    hostDefaults.modules = [
      ./common/vfio.nix
      ./common/ccache.nix
      {
        # make this flake's nixpkgs available to the whole system
        nix = {
          generateNixPathFromInputs = true;
          generateRegistryFromInputs = true;
          linkInputs = true;
        };
        nixpkgs.overlays = [(self: super: import ./pkgs { pkgs = super; })];
      }
    ];
    hosts = {
      nixmsi = {
        system = "x86_64-linux";
        modules = [
          ./hosts/nixmsi.nix
          impermanence.nixosModule
          nix-gaming.nixosModules.pipewireLowLatency
          hw.common-pc-ssd # enables fstrim
          hw.common-cpu-amd # microcode
          hw.common-cpu-amd-pstate # amd-pstate
          hw.common-gpu-amd # configures drivers
          hw.common-pc-laptop # enables tlp
          (getPriv "nixmsi")
        ];
        extraArgs = {
          inherit nixpkgs;
        };
      };
    };
  };
}
