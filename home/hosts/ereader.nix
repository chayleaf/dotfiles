{ pkgs
, inputs
, ...
}:

{
  imports = [
    ../modules/general.nix
    ../modules/i3-sway.nix
    inputs.nur.modules.homeManager.default
  ];

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
