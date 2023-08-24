{ config
, lib
, pkgs
, ...}:

let
  cfg = config.services.scanservjs;
  /*
    substituteInPlace src/classes/config.js \
      --replace '/usr/bin/scanimage' '${sane-backends}/bin/scanimage' \
      --replace '/usr/bin/convert' '${imagemagick}/bin/convert' \
      --replace '/usr/bin/tesseract' '${tesseract}/bin/tesseract'
  */
  settings = {
    scanimage = "${pkgs.sane-backends}/bin/scanimage";
    convert = "${pkgs.imagemagick}/bin/convert";
    tesseract = "${pkgs.tesseract}/bin/tesseract";
    # it defaults to config/devices.json, but "config" dir doesn't exist and scanservjs doesn't create it
    devicesPath = "devices.json";
  } // cfg.settings;
  settingsFormat = pkgs.formats.json { };

  leafs = attrs:
    builtins.concatLists
      (lib.mapAttrsToList
        (k: v: if builtins.isAttrs v then leafs v else [v])
        attrs);

  package = pkgs.scanservjs;

  # config.host = '127.0.0.1';
  # config.port = 8080;
  # config.devices = [];
  # config.ocrLanguage = 'eng';
  # config.log.level = 'DEBUG';
  # config.scanimage = '/usr/bin/scanimage';
  # config.convert = '/usr/bin/convert';
  # config.tesseract = '/usr/bin/tesseract';
  # config.previewResolution = 100;
  configFile = pkgs.writeText "config.local.js" ''
    /* eslint-disable no-unused-vars */
    module.exports = {
      afterConfig(config) {
        ${builtins.concatStringsSep ""
          (leafs
            (lib.mapAttrsRecursive (path: val: ''
              ${builtins.concatStringsSep "." path} = ${builtins.toJSON val};
            '') { config = settings; }))}
        ${cfg.extraConfig}
      },

      afterDevices(devices) {
        ${cfg.extraDevicesConfig}
      },

      async afterScan(fileInfo) {
        ${cfg.runAfterScan}
      },

      actions: [
        ${builtins.concatStringsSep ",\n" cfg.extraActions}
      ],
    };
  '';

in {
  options.services.scanservjs = {
    enable = lib.mkEnableOption (lib.mdDoc "scanservjs");
    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/scanservjs";
      description = lib.mdDoc ''
        State directory for scanservjs
      '';
    };
    settings = lib.mkOption {
      default = {};
      description = lib.mdDoc ''
        Config to set in config.local.js's `afterConfig`
      '';
      type = lib.types.submodule {
        freeformType = settingsFormat.type;
        options.host = lib.mkOption {
          type = lib.types.str;
          description = "The IP to listen on";
          default = "127.0.0.1";
        };
        options.port = lib.mkOption {
          type = lib.types.port;
          description = "The port to listen on";
          default = 8080;
        };
      };
    };
    extraConfig = lib.mkOption {
      default = "";
      type = lib.types.lines;
      description = lib.mdDoc ''
        Extra code to add to config.local.js's `afterConfig`
      '';
    };
    extraDevicesConfig = lib.mkOption {
      default = "";
      type = lib.types.lines;
      description = lib.mdDoc ''
        Extra code to add to config.local.js's `afterDevices`
      '';
    };
    runAfterScan = lib.mkOption {
      default = "";
      type = lib.types.lines;
      description = lib.mdDoc ''
        Extra code to add to config.local.js's `afterScan`
      '';
    };
    extraActions = lib.mkOption {
      default = [];
      type = lib.types.listOf lib.types.lines;
      description = "Actions to add to config.local.js's `actions`";
    };
  };
  config = lib.mkIf cfg.enable {
    hardware.sane.enable = true;
    users.users.scanservjs = {
      group = "scanservjs";
      extraGroups = [ "scanner" "lp" ];
      home = cfg.stateDir;
      isSystemUser = true;
      createHome = true;
    };
    users.groups.scanservjs = {};

    systemd.services.scanservjs = {
      description = "scanservjs";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      # yes, those paths are configurable, but the config option isn't always used...
      path = with pkgs; [ coreutils sane-backends imagemagick tesseract ];
      environment.NIX_SCANSERVJS_CONFIG_PATH = configFile;
      environment.SANE_CONFIG_DIR = "/etc/sane-config";
      environment.LD_LIBRARY_PATH = "/etc/sane-libs";
      serviceConfig = {
        ExecStart = "${package}/bin/scanservjs";
        Restart = "always";
        User = "scanservjs";
        Group = "scanservjs";
        WorkingDirectory = cfg.stateDir;
      };
    };
  };
}
