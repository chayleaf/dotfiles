{ lib
, pkgs
, config
, ... }:

{
  options.common = with lib; mkOption {
    type = types.submodule {
      options = {
        workstation = mkOption {
          type = types.bool;
          default = false;
          description = "whether this device is a workstation (meaning a device for personal use rather than a server/embedded device)";
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
      package = pkgs.nixFlakes;
      extraOptions = ''
        experimental-features = nix-command flakes
      '';
      # from flake-utils-plus: make this flake's nixpkgs available to the whole system
      generateNixPathFromInputs = true;
      generateRegistryFromInputs = true;
      linkInputs = true;
    };
    systemd.services.nix-daemon.serviceConfig.LimitSTACKSoft = "infinity";
    boot.kernelParams = [
      "consoleblank=60"
    ];

    nixpkgs.overlays = [ (self: super: import ../pkgs { pkgs = super; inherit lib; }) ];
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
    ] ++ (if cfg.workstation then [
      comma
      neovim
      man-pages man-pages-posix
    ] else [
      kitty.terminfo
      # rxvt-unicode-unwrapped.terminfo
      vim
      tmux
    ]));
    documentation.dev.enable = lib.mkIf cfg.workstation true;
    programs.fish.enable = true;
    /*programs.zsh = {
      enable = true;
      enableBashCompletion = true;
    };*/
    users.defaultUserShell = lib.mkIf (!cfg.workstation) pkgs.fish;
    users.users.${cfg.mainUsername} = {
      uid = 1000;
      isNormalUser = true;
      extraGroups = [ "wheel" ];
    };
    services.xserver.libinput.enable = lib.mkIf cfg.workstation true;
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
    programs.sway.enable = lib.mkIf cfg.workstation true;
    services.dbus.enable = lib.mkIf cfg.workstation true;
    security.polkit.enable = lib.mkIf cfg.workstation true;
    # pipewire:
    security.rtkit.enable = lib.mkIf cfg.workstation true;
    services.pipewire = lib.mkIf cfg.workstation {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };
    programs.fuse.userAllowOther = true;
    xdg.portal = lib.mkIf cfg.workstation {
      enable = true;
      extraPortals = with pkgs; [ xdg-desktop-portal-gtk xdg-desktop-portal-wlr ];
    };
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
