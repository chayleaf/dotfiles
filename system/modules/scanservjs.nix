{ }
/*
  { config
  , lib
  , pkgs
  , ...}:

  let
    cfg = config.services.scanservjs;

    settings = {
      scanimage = "${pkgs.sane-backends}/bin/scanimage";
      convert = "${pkgs.imagemagick}/bin/convert";
      tesseract = "${pkgs.tesseract}/bin/tesseract";
    } // cfg.settings;

    settingsFormat = pkgs.formats.json { };

    leafs = attrs:
      builtins.concatLists
        (lib.mapAttrsToList
          (k: v: if builtins.isAttrs v then leafs v else [ v ])
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
    /* eslint-disable no-unused-vars
*/
/*
    configFile = pkgs.writeText "config.local.js" ''
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
          ${builtins.concatStringsSep ",\n" (map (x: "(${x})") cfg.extraActions)}
        ],
      };
    '';

  in {
    disabledModules = [ "services/hardware/scanservjs.nix" ];

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
        default = { };
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
        default = [ ];
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
        createHome = lib.mkIf (cfg.stateDir != "/var/lib/scanservjs") true;
      };
      users.groups.scanservjs = { };

      systemd.services.scanservjs = {
        description = "scanservjs";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        # yes, those paths are configurable, but the config option isn't always used...
        path = with pkgs; [ coreutils sane-backends imagemagick tesseract ];
        environment.SANE_CONFIG_DIR = "/etc/sane-config";
        environment.LD_LIBRARY_PATH = "/etc/sane-libs";
        serviceConfig = {
          ExecStart = "${package}/bin/scanservjs --config ${configFile}";
          Restart = "always";
          User = "scanservjs";
          Group = "scanservjs";
          StateDirectory = lib.mkIf (cfg.stateDir == "/var/lib/scanservjs") "scanservjs";
          WorkingDirectory = cfg.stateDir;
        };
      };
    };
  }
*/
