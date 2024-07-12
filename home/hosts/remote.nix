{ inputs
, ...
}:

{
  imports = [
    ../modules/general.nix
    inputs.nur.nixosModules.nur
  ];

  home.stateVersion = "24.05";
  home.username = "chayleaf";
  home.homeDirectory = "/home/chayleaf";
  minimal = true;
}
