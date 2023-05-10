{ pkgs, ... }: let inherit (pkgs) callPackage; in {
  system76-scheduler = callPackage ./system76-scheduler.nix { };
  maubot = callPackage ./maubot.nix { };
  pineapplebot = callPackage ./pineapplebot.nix { };
}
