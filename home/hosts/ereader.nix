{
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    ../modules/general.nix
    ../modules/i3-sway.nix
    inputs.nur.modules.homeManager.default
  ];

  phone.enable = true;
  phone.suspend = false;
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
    koreader2
    #(calibre.override {
    #  speechSupport = false;
    #})
    wvkbd
  ];
  wayland.windowManager.sway.config.startup = [
    {
      command = toString (
        pkgs.writeShellScript "run-koreader" ''
          while true; do
            ${lib.getExe pkgs.koreader2}
            sleep 5
          done
        ''
      );
    }
  ];
  services.swayidle.enable = lib.mkForce false;
  programs.bash.profileExtra = ''
    if [ -z "$WAYLAND_DISPLAY" ] && [ -n "$XDG_VTNR" ] && [ "$XDG_VTNR" -eq 1 ]; then
      systemctl stop buffyboard
      sway
    fi
  '';
}
