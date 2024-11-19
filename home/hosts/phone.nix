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
    inputs.nur.modules.homeManager.default
  ];

  phone.enable = true;
  phone.suspend = false;
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
