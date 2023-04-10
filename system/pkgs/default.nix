{ pkgs, ... }: let inherit (pkgs) callPackage; in {
  system76-scheduler = callPackage ../pkgs/system76-scheduler.nix { };
}
