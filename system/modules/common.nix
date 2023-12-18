{ lib
, pkgs
, config
, inputs
, ... }:

let
  # force some defaults even if they were set with mkDefault already...
  mkForceDefault = lib.mkOverride 999;
  cfg = config.common;
in {
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
  config = lib.mkMerge [
  {
    nix = {
      # nix.channel.enable is needed for NIX_PATH to work for some reason
      # channel.enable = false;
      settings = {
        allowed-users = [ cfg.mainUsername ];
        auto-optimise-store = true;
        use-xdg-base-directories = true;
        experimental-features = [
          "ca-derivations"
          "flakes"
          "nix-command"
          "no-url-literals"
          "repl-flake"
        ];
      };
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 30d";
      };
      package = pkgs.nixForNixPlugins;
      extraOptions = ''
        plugin-files = ${pkgs.nix-plugins.override { nix = config.nix.package; }}/lib/nix/plugins/libnix-extra-builtins.so
      '';
    };
    systemd.services.nix-daemon.serviceConfig.LimitSTACKSoft = "infinity";
    nix.daemonCPUSchedPolicy = lib.mkDefault "idle";
    nix.daemonIOSchedClass = lib.mkDefault "idle";

    # registry is used for the new flaky nix command
    nix.registry =
      builtins.mapAttrs
      (_: v: { flake = v; })
      (lib.filterAttrs (_: v: v?outputs) inputs);

    # add import'able flake inputs (like nixpkgs) to nix path
    # nix path is used for old nix commands (like nix-build, nix-shell)
    environment.etc = lib.mapAttrs'
      (name: value: {
        name = "nix/inputs/${name}";
        value.source = value.outPath;
      })
      (lib.filterAttrs (_: v: builtins.pathExists "${v}/default.nix") inputs);
    nix.nixPath = [ "/etc/nix/inputs" ];

    boot.kernelParams = lib.optionals (cfg.resolution != null) [
      "consoleblank=60"
    ] ++ lib.optionals (cfg.resolution == "1920x1080") [
      "fbcon=font:TER16x32"
    ];
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
    environment.systemPackages = with pkgs; [
      bottom
      wget
      git
      tmux
    ];
    programs.fish.enable = true;
    users.users.${cfg.mainUsername} = {
      uid = 1000;
      isNormalUser = true;
      extraGroups = [ "wheel" ];
    };
    # nixos-hardware uses mkDefault here, so we use slightly higher priority
    services.xserver.libinput.enable = mkForceDefault (!cfg.minimal);
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
  }

  (lib.mkIf cfg.minimal {
    environment.systemPackages = with pkgs; [
      kitty.terminfo
      # rxvt-unicode-unwrapped.terminfo
    ];
    programs.fish.interactiveShellInit = ''
      set -gx SHELL ${pkgs.zsh}/bin/zsh
      set -g fish_color_autosuggestion 777 brblack
      set -g fish_color_command green
      set -g fish_color_operator white
      set -g fish_color_param white
      set -g fish_key_bindings fish_vi_key_bindings
      set -g fish_cursor_insert line
      set -g fish_cursor_replace underscore
    '';
    # this is supposed to default to false, but it doesn't because of nixos fish module
    documentation.man.generateCaches = mkForceDefault false;
    # we don't need stuff like html files (NixOS manual and so on) on minimal machines
    documentation.doc.enable = lib.mkDefault false;
    # conflicts with bash module's mkDefault
    # only override on minimal systems because on non-minimal systems
    # my fish config doesn't work well in fb/drm console
    users.defaultUserShell = lib.mkIf cfg.minimal (mkForceDefault pkgs.fish);

    programs.vim = {
      defaultEditor = lib.mkDefault true;
      package = pkgs.vim-full.customize {
        vimrcConfig.customRC = ''
          syntax on
          au FileType markdown set colorcolumn=73 textwidth=72
          au FileType gitcommit set colorcolumn=73
          au BufReadPre * set foldmethod=syntax
          au BufReadPost * folddoc foldopen!
          autocmd BufReadPost * if @% !~# '\.git[\/\\]COMMIT_EDITMSG$' && line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g`\"" | endif
        '';
        vimrcConfig.packages.myVimPackage = with pkgs.vimPlugins; {
          start = [ vim-sleuth ];
        };
      };
    };
  })

  (lib.mkIf (!cfg.minimal) {
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };
    security.polkit.enable = true;
    security.rtkit.enable = true;
    services.dbus.enable = true;
  })

  ];
}
