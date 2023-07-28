{ lib
, pkgs
, config
, ... }:

{
  options.common = with lib; mkOption {
    type = types.submodule {
      options = {
        minimal = mkOption {
          type = types.bool;
          default = true;
          description = "whether this is a minimal (no DE/WM) system";
        };
        mainUsername = mkOption {
          type = types.str;
          default = "user";
          description = "main user's username";
        };
        gettyAutologin = mkOption {
          type = types.bool;
          default = false;
          description = "make getty autologin to the main user";
        };
        resolution = mkOption {
          type = with types; nullOr str;
          default = null;
          description = "resolution (none/1280x720/1920x1080)";
        };
      };
    };
    default = { };
  };
  config = let
    cfg = config.common;
  in {
    nix = {
      settings = {
        allowed-users = [ cfg.mainUsername ];
        auto-optimise-store = true;
      };
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 30d";
      };
      package = pkgs.nixForNixPlugins;
      extraOptions = ''
        experimental-features = nix-command flakes
      '';
    };
    systemd.services.nix-daemon.serviceConfig.LimitSTACKSoft = "infinity";
    boot.kernelParams = lib.optionals (cfg.resolution != null) [
      "consoleblank=60"
    ] ++ (lib.optionals (cfg.resolution == "1920x1080") [
      "fbcon=font:TER16x32"
    ]);
    console.font =
      lib.mkIf (cfg.resolution == "1920x1080" || cfg.resolution == "1366x768") {
        "1920x1080" = "${pkgs.terminus_font}/share/consolefonts/ter-v32n.psf.gz";
        "1366x768" = "${pkgs.terminus_font}/share/consolefonts/ter-v24n.psf.gz";
      }.${cfg.resolution};
    boot.loader.grub = lib.mkIf (cfg.resolution != null) {
      gfxmodeEfi = cfg.resolution;
      gfxmodeBios = cfg.resolution;
    };

    networking.usePredictableInterfaceNames = lib.mkDefault true;

    hardware.enableRedistributableFirmware = true;
    services.openssh.settings.PasswordAuthentication = false;
    services.tlp.settings.USB_EXCLUDE_PHONE = 1;
    services.tlp.settings.START_CHARGE_THRESH_BAT0 = 75;
    services.tlp.settings.STOP_CHARGE_THRESH_BAT0 = 80;
    i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
    i18n.supportedLocales = lib.mkDefault [
      "C.UTF-8/UTF-8"
      "en_US.UTF-8/UTF-8"
      "en_DK.UTF-8/UTF-8"
    ];
    # ISO-8601
    i18n.extraLocaleSettings.LC_TIME = "en_DK.UTF-8";
    environment.systemPackages = with pkgs; ([
      wget
      git
      tmux
    ] ++ lib.optionals cfg.minimal [
      kitty.terminfo
      # rxvt-unicode-unwrapped.terminfo
      vim
    ]);
    # this is supposed to default to false, but it doesn't because of nixos fish module
    documentation.man.generateCaches = lib.mkOverride 999 false;
    # and we don't need html files and so on on minimal machines (it's not like I ever use it anyway)
    # as a bonus, this disables the HTML NixOS manual which takes a while to build and which I
    # definitely don't need on minimal machines
    documentation.doc.enable = lib.mkIf cfg.minimal (lib.mkDefault false);
    programs.fish.enable = true;
    users.defaultUserShell = lib.mkDefault pkgs.fish;
    users.users.${cfg.mainUsername} = {
      uid = 1000;
      isNormalUser = true;
      extraGroups = [ "wheel" ];
    };
    # nixos-hardware uses mkDefault here, so we use slightly higher priority
    services.xserver.libinput.enable = lib.mkOverride 999 (!cfg.minimal);
    # TODO: minimal fish/vim config
    /*
    services.xserver = {
      enable = true;
      libinput.enable = true;
      desktopManager.xterm.enable = false;
      # I couldn't get lightdm to start sway, so let's just do this
      displayManager.startx.enable = true;
      windowManager.i3.enable = true;
    };
    */
    # pipewire:
    programs.fuse.userAllowOther = true;
    # autologin once after boot
    # --skip-login means directly call login instead of first asking for username
    # (normally login asks for username too, but getty prefers to do it by itself for whatever reason)
    services.getty.extraArgs = lib.mkIf cfg.gettyAutologin [ "--skip-login" ];
    services.getty.loginProgram = lib.mkIf cfg.gettyAutologin (let
      lockfile = "/tmp/login-once.lock";
    in with pkgs; writeShellScript "login-once" ''
      if [ -f '${lockfile}' ]; then
        exec ${shadow}/bin/login $@
      else
        ${coreutils}/bin/touch '${lockfile}'
        exec ${shadow}/bin/login -f user
      fi
    '');
  };
}
