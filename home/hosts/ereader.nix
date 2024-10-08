{ pkgs
, inputs
, ...
}:

{
  imports = [
    ../modules/general.nix
    ../modules/i3-sway.nix
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
  minimal = true;
  home.stateVersion = "23.11";
  home.username = "user";
  home.homeDirectory = "/home/user";
  terminals = [ "foot" ];
  wayland.windowManager.sway.enable = true;
  # terminals = [ "kitty" ];
  # xsession.windowManager.i3.enable = true;

  # services.kdeconnect.enable = true;
  home.packages = with pkgs; [
    # TODO fix
    koreader
    (calibre.override {
      speechSupport = false;
    })
    wvkbd
  ];
}
