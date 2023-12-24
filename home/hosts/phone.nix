{ pkgs
, inputs,
...
}:

{
  imports = [
    ../modules/general.nix
    ../modules/firefox.nix
    ../modules/i3-sway.nix
    ../modules/nvim.nix
    inputs.nur.nixosModules.nur
  ];

  nix.settings = {
    trusted-public-keys = [
      "binarycache.pavluk.org:Vk0ms/vSqoOV2JXeNVOroc8EfilgVxCCUtpCShGIKsQ="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
    trusted-substituters = [
      "https://binarycache.pavluk.org"
      "https://cache.nixos.org"
    ];
  };

  phone.enable = true;
  home.stateVersion = "23.11";
  home.username = "user";
  home.homeDirectory = "/home/user";
  terminals = [ "foot" "kitty" ];
  wayland.windowManager.sway.enable = true;
  services.kdeconnect.enable = true;
  home.packages = with pkgs; [
    squeekboard
    techmino
    tdesktop
  ];
}
