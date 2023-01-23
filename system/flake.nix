{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    utils.url = "github:gytis-ivaskevicius/flake-utils-plus";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs = inputs@{ self, nixpkgs, utils, nixos-hardware }:
  let
    hw = nixos-hardware.nixosModules;
    # IRL-related stuff I'd rather not put into git
    priv = import ./private.nix inputs;
  in utils.lib.mkFlake {
    inherit self inputs;
    hostDefaults.modules = [
      ./common/vfio.nix
      {
        # make this flake's nixpkgs available to the whole system
        nix = {
          generateNixPathFromInputs = true;
          generateRegistryFromInputs = true;
          linkInputs = true;
        };
      }
    ];
    hosts = {
      nixmsi = {
        system = "x86_64-linux";
        modules = [
          priv.nixmsi
          ./hosts/nixmsi.nix
          hw.common-pc-ssd # enables fstrim
          hw.common-cpu-amd # microcode
          hw.common-cpu-amd-pstate # amd-pstate
          hw.common-gpu-amd # configures drivers
          hw.common-pc-laptop # enables tlp
        ];
      };
    };
  };
}
